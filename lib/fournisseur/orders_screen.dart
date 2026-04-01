import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String selectedFilter = 'Toutes';
  List<Map<String, dynamic>> orders = [];
  bool _loading = false;
  String? _error;

  // ✅ Cooldown — prevent rapid repeated calls (fixes 429)
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // ── Load ALL commandes for fournisseur ────────────────────
  Future<void> _loadOrders() async {
    final rawRes = await http.get(
      Uri.parse('https://pfe-backend-nwmy.onrender.com/api/commandes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiService.token}',
      },
    );
    print('RAW STATUS: ${rawRes.statusCode}');
    print('RAW BODY: ${rawRes.body}');
    // ✅ Block if called less than 10 seconds after last fetch
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 10)) {
      return;
    }
    _lastFetch = DateTime.now();

    setState(() { _loading = true; _error = null; });
    try {
      // ✅ Single clean call — no duplicate raw debug http call
      final data = await ApiService.getCommandes();

      if (data.isEmpty) {
        setState(() { orders = []; _loading = false; });
        return;
      }

      setState(() {
        orders = data.map<Map<String, dynamic>>((e) {
          final id        = (e['_id'] ?? e['id'] ?? '').toString();
          final capacite  = (e['capacite'] as num?)?.toDouble() ?? 0.0;
          final prix      = (e['prix'] as num?)?.toDouble() ?? 0.0;
          final rawStatus = (e['status'] ?? e['statut'] ?? 'en attente').toString();
          final status    = _mapStatut(rawStatus);

          final client = e['client'];
          String clientName = 'Client';
          if (client is Map) {
            final nom    = client['nom']    ?? '';
            final prenom = client['prenom'] ?? '';
            clientName   = '$nom $prenom'.trim();
            if (clientName.isEmpty) clientName = client['email'] ?? 'Client $id';
          }

          return {
            'id':         id,
            'clientName': clientName,
            'address':    e['adresse'] ?? e['address'] ?? 'Adresse non renseignée',
            'quantity':   capacite,
            'price':      prix > 0 ? prix : capacite * 2,
            'distance':   (e['distanceKm'] as num?)?.toDouble() ?? 0.0,
            'duration':   (e['durationMin'] as num?)?.toInt()   ?? 0,
            'status':     status,
            'rawStatus':  rawStatus,
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error   = 'Impossible de contacter le serveur.';
        _loading = false;

      });
    }
  }

  String _mapStatut(String statut) {
    switch (statut) {
      case 'en livraison': return 'accepted';
      case 'livrée':       return 'delivered';
      case 'annulée':      return 'refused';
      default:             return 'pending';
    }
  }

  // ── Accept order ──────────────────────────────────────────
  Future<void> _acceptOrder(String orderId) async {
    setState(() => _loading = true);
    try {
      final chauffeurs = await ApiService.getMyChauffeurs();

      if (chauffeurs.isEmpty) {
        _showError('Aucun chauffeur trouvé. Ajoutez un chauffeur d\'abord.');
        setState(() => _loading = false);
        return;
      }

      final available = chauffeurs.where((c) {
        final dispo = c['disponible'];
        return dispo == true || dispo == 1;
      }).toList();

      if (available.isEmpty) {
        _showError('Tous vos chauffeurs sont occupés.');
        setState(() => _loading = false);
        return;
      }

      final chauffeurId = (available.first['_id'] ?? available.first['id']).toString();

      final result = await ApiService.assignCommande(
        commandeId:  orderId,
        chauffeurId: chauffeurId,
      );

      if (result['error'] != null) {
        _showError(result['error']);
      } else {
        // ✅ Update local state
        setState(() {
          final idx = orders.indexWhere((o) => o['id'] == orderId);
          if (idx != -1) orders[idx]['status'] = 'accepted';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Commande acceptée et chauffeur assigné ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        }

        // ✅ Send to Python for VRP optimization
        final order = orders.firstWhere(
              (o) => o['id'] == orderId,
          orElse: () => {},
        );

        if (order.isNotEmpty) {
          // 1 — Send chauffeurs to Python
          final fournisseurInfo = await ApiService.getMyInfo();
          final fLat = (fournisseurInfo['position']?['lat'] as num?)?.toDouble() ?? 0.0;
          final fLon = (fournisseurInfo['position']?['lon'] as num?)?.toDouble() ?? 0.0;
          await ApiService.setupConducteurs(
            chauffeurs:     chauffeurs,
            fournisseurLat: fLat,
            fournisseurLon: fLon,
          );

          // 2 — Send commande to Python
          await ApiService.sendCommandeToPython(
            id:     orderId,
            lat:    (order['position']?['lat'] as num?)?.toDouble() ?? order['lat'] ?? 0.0,
            lon:    (order['position']?['lon'] as num?)?.toDouble() ?? order['lon'] ?? 0.0,
            demand: (order['quantity'] as num?)?.toDouble() ?? 0.0,
          );

          // 3 — Accept in Python
          await ApiService.acceptCommandePython(orderId);

          // 4 — Run NSGA-II
          final optimResult = await ApiService.optimize();

          if (optimResult['error'] == null && mounted) {
            final dist  = (optimResult['distance_totale_km'] as num?)?.toStringAsFixed(1) ?? '?';
            final valid = optimResult['valide'] as bool? ?? false;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✓ Routes optimisées — $dist km${valid ? "" : " (invalide)"}'),
              backgroundColor: const Color(0xFF1E3A8A),
              duration: const Duration(seconds: 4),
            ));
          }
        }
      }
    } catch (e) {
      _showError('Erreur réseau: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // ── Refuse order ──────────────────────────────────────────
  Future<void> _refuseOrder(String orderId) async {
    try {
      final result = await ApiService.cancelCommande(orderId);

      if (result['error'] != null) {
        _showError(result['error']);
      } else {
        setState(() {
          final idx = orders.indexWhere((o) => o['id'] == orderId);
          if (idx != -1) orders[idx]['status'] = 'refused';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Commande refusée'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      _showError('Erreur réseau: $e');
    }
  }

  // ── Route optimization ────────────────────────────────────
  Future<void> _runOptimization() async {
    setState(() => _loading = true);
    try {
      final chauffeurs     = await ApiService.getMyChauffeurs();
      final acceptedOrders = orders.where((o) => o['status'] == 'accepted').toList();

      final result = await ApiService.optimiseRoute({
        'fournisseurId': ApiService.userId,
        'chauffeurs':    chauffeurs,
        'commandes':     acceptedOrders,
      });

      if (result['error'] != null) {
        _showError('Erreur optimisation: ${result['error']}');
      } else {
        final dist  = (result['distance_totale_km'] as num?)?.toStringAsFixed(1) ?? '?';
        final valid = result['valide'] as bool? ?? false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✓ Routes optimisées — $dist km total${valid ? "" : " (invalide)"}'),
            backgroundColor: const Color(0xFF1E3A8A),
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (e) {
      _showError('Erreur optimisation: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── Filter ────────────────────────────────────────────────
  List<Map<String, dynamic>> get filteredOrders {
    if (selectedFilter == 'Toutes')     return orders;
    if (selectedFilter == 'En attente') return orders.where((o) => o['status'] == 'pending').toList();
    if (selectedFilter == 'Acceptées')  return orders.where((o) => o['status'] == 'accepted').toList();
    if (selectedFilter == 'Livrées')    return orders.where((o) => o['status'] == 'delivered').toList();
    return orders;
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Commandes'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadOrders,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.alt_route),
            onPressed: _loading ? null : _runOptimization,
            tooltip: 'Optimiser routes',
          ),
        ],
      ),
      body: Column(
        children: [
          // Error banner
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.warning, color: Colors.deepOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Colors.deepOrange, fontSize: 13))),
                TextButton(onPressed: _loadOrders, child: const Text('Réessayer')),
              ]),
            ),

          // Loading bar
          if (_loading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFBBDEFB),
              color: Color(0xFF1E3A8A),
            ),

          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _buildFilterChip('Toutes'),
                const SizedBox(width: 5),
                _buildFilterChip('En attente'),
                const SizedBox(width: 5),
                _buildFilterChip('Acceptées'),
                const SizedBox(width: 5),
                _buildFilterChip('Livrées'),
              ]),
            ),
          ),

          // Summary bar
          if (orders.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryBadge('En attente',
                      orders.where((o) => o['status'] == 'pending').length,
                      Colors.orange),
                  _buildSummaryBadge('Acceptées',
                      orders.where((o) => o['status'] == 'accepted').length,
                      Colors.green),
                  _buildSummaryBadge('Livrées',
                      orders.where((o) => o['status'] == 'delivered').length,
                      Colors.blue),
                  _buildSummaryBadge('Annulées',
                      orders.where((o) => o['status'] == 'refused').length,
                      Colors.red),
                ],
              ),
            ),

          // Orders list
          Expanded(
            child: filteredOrders.isEmpty && !_loading
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) =>
                    _buildOrderCard(filteredOrders[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, int count, Color color) {
    return Column(children: [
      Text('$count',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final isPending   = order['status'] == 'pending';
    final isAccepted  = order['status'] == 'accepted';
    final isDelivered = order['status'] == 'delivered';
    final isRefused   = order['status'] == 'refused';

    Color    statusColor = Colors.orange;
    String   statusLabel = 'En attente';
    IconData statusIcon  = Icons.hourglass_empty;

    if (isAccepted)  { statusColor = Colors.green; statusLabel = 'Acceptée';  statusIcon = Icons.check_circle; }
    if (isDelivered) { statusColor = Colors.blue;  statusLabel = 'Livrée';    statusIcon = Icons.done_all; }
    if (isRefused)   { statusColor = Colors.red;   statusLabel = 'Annulée';   statusIcon = Icons.cancel; }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.person, color: Color(0xFF1E3A8A), size: 20),
              const SizedBox(width: 8),
              Text(order['clientName'],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: TextStyle(color: statusColor,
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 10,),

          // Address
          Row(children: [
            Icon(Icons.location_on, color: Colors.red[400], size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(order['address'],
                style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
          ]),
          const SizedBox(height: 8),

          // Info chips

          Container(
            padding: const EdgeInsets.all(1),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row( children: [
              _buildInfoChip(Icons.water_drop, '${order['quantity']} L',   Colors.blue, ),
              _buildInfoChip(Icons.route,      '${order['distance']} km',  Colors.orange),
              _buildInfoChip(Icons.timer,      '${order['duration']} min', Colors.purple),
              _buildInfoChip(Icons.payments,   '${order['price']} DA',     Colors.green),
              ],
            ),
            ),
          ),

          // Action buttons (only for pending)
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _acceptOrder(order['id']),

                icon: const Icon(Icons.check, size: 20),
                label: const Text('Accepter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _refuseOrder(order['id']),
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Refuser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12,
            fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('Aucune commande',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Les nouvelles demandes apparaîtront ici',
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loadOrders,
          icon: const Icon(Icons.refresh),
          label: const Text('Rafraîchir'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
        ),
      ]),
    );
  }
}