import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _baseUrl = 'http://10.0.2.2:8000';

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // ── Load orders from API ─────────────────────────────────
  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/commandes'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          orders = data.map((e) => {
            'id':         e['id'].toString(),
            'clientName': e['description'].isNotEmpty ? e['description'] : 'Client ${e['id']}',
            'address':    'GPS: ${(e['lat'] as num).toStringAsFixed(4)}, ${(e['lon'] as num).toStringAsFixed(4)}',
            'quantity':   e['demand'],
            'distance':   0.0,
            'price':      (e['demand'] as int) * 2,
            'status':     _mapStatut(e['statut']),
            'lat':        e['lat'],
            'lon':        e['lon'],
          }).toList();
        });
      } else {
        setState(() => _error = 'Erreur chargement commandes');
      }
    } catch (e) {
      setState(() => _error = 'Impossible de contacter le serveur.\nVérifiez que le backend tourne.');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _mapStatut(String statut) {
    switch (statut) {
      case 'acceptee': return 'accepted';
      case 'refusee':  return 'refused';
      default:         return 'pending';
    }
  }

  // ── Accept order → then auto run full optimization ───────
  Future<void> _acceptOrder(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/commandes/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'commande_id': int.parse(orderId)}),
      );
      if (res.statusCode == 200) {
        setState(() {
          final order = orders.firstWhere((o) => o['id'] == orderId);
          order['status'] = 'accepted';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Commande acceptée ! Calcul des routes...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        }
        // Automatically run full setup + optimization
        await _runFullOptimization();
      } else {
        _showError('Erreur lors de l\'acceptation');
      }
    } catch (e) {
      _showError('Erreur réseau');
    }
  }

  // ── Refuse order ─────────────────────────────────────────
  Future<void> _refuseOrder(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/commandes/refuse'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'commande_id': int.parse(orderId)}),
      );
      if (res.statusCode == 200) {
        setState(() {
          final order = orders.firstWhere((o) => o['id'] == orderId);
          order['status'] = 'refused';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Commande refusée'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ));
        }
      } else {
        _showError('Erreur lors du refus');
      }
    } catch (e) {
      _showError('Erreur réseau');
    }
  }

  // ── FULL PIPELINE ─────────────────────────────────────────
  // 1. Register conducteurs
  // 2. Build road graph
  // 3. Run NSGA-II
  // After this, suivi.dart calls GET /solution and draws the map
  Future<void> _runFullOptimization() async {
    setState(() => _loading = true);
    try {
      // STEP 1 — Setup conducteurs
      // TODO: replace with real driver data from your database
      final setupRes = await http.post(
        Uri.parse('$_baseUrl/setup/conducteurs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([
          {'id': 1, 'capacity': 400, 'lat': 36.7600, 'lon': 3.0500, 'nom': 'Conducteur A'},
          {'id': 2, 'capacity': 400, 'lat': 36.7450, 'lon': 3.0700, 'nom': 'Conducteur B'},
          {'id': 3, 'capacity': 400, 'lat': 36.7580, 'lon': 3.0800, 'nom': 'Conducteur C'},
        ]),
      );
      if (setupRes.statusCode != 200) {
        _showError('Erreur setup conducteurs (étape 1)');
        return;
      }

      // STEP 2 — Init road graph
      final graphRes = await http.post(
        Uri.parse('$_baseUrl/setup/init-graph?num_nodes=30'),
      );
      if (graphRes.statusCode != 200) {
        _showError('Erreur graphe routier (étape 2)');
        return;
      }

      // STEP 3 — Run NSGA-II optimization
      final optRes = await http.post(
        Uri.parse('$_baseUrl/optimize?pop_size=30&generations=80'),
      );
      if (optRes.statusCode == 200) {
        final data = jsonDecode(optRes.body);
        final dist = (data['total_distance_km'] as num).toStringAsFixed(1);
        final valid = data['valid'] as bool;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              '✓ Routes optimisées — $dist km total${valid ? "" : " (invalide)"}',
            ),
            backgroundColor: const Color(0xFF1E3A8A),
            duration: const Duration(seconds: 4),
          ));
        }
      } else {
        _showError('Erreur optimisation NSGA-II (étape 3)');
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── FILTER ───────────────────────────────────────────────
  List<Map<String, dynamic>> get filteredOrders {
    if (selectedFilter == 'Toutes') return orders;
    if (selectedFilter == 'En attente') {
      return orders.where((o) => o['status'] == 'pending').toList();
    }
    return orders.where((o) => o['status'] == 'accepted').toList();
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
            onPressed: _loadOrders,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.alt_route),
            onPressed: _loading ? null : _runFullOptimization,
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
            child: Row(children: [
              _buildFilterChip('Toutes'),
              const SizedBox(width: 1),
              _buildFilterChip('En attente'),
              const SizedBox(width: 1),
              _buildFilterChip('Acceptées'),
            ]),
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
    final isPending  = order['status'] == 'pending';
    final isAccepted = order['status'] == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            if (isAccepted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 4),
                  Text('Acceptée',
                      style: TextStyle(color: Colors.green[700],
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            if (order['status'] == 'refused')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Refusée',
                    style: TextStyle(color: Colors.red[700],
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 12),

          // Address
          Row(children: [
            Icon(Icons.location_on, color: Colors.red[400], size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(order['address'],
                style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
          ]),
          const SizedBox(height: 8),

          // Info chips
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildInfoChip(Icons.water_drop, '${order['quantity']} L', Colors.blue),
            _buildInfoChip(Icons.route, '${order['distance']} km', Colors.orange),
            _buildInfoChip(Icons.payments, '${order['price']} DA', Colors.green),
          ]),

          // Action buttons
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