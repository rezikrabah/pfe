import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // ✅ ApiService import

class ClientTrackingPage extends StatefulWidget {
  final String commandeId;
  final String clientId;

  const ClientTrackingPage({
    super.key,
    required this.commandeId,
    required this.clientId,
  });

  @override
  State<ClientTrackingPage> createState() => _ClientTrackingPageState();
}

class _ClientTrackingPageState extends State<ClientTrackingPage> {
  final MapController _mapController = MapController();
  Timer? _timer;

  String _statut   = 'en_attente';
  LatLng? _driverPos;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTracking();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchTracking());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTracking() async {
    try {
      // ✅ Use Node.js backend via ApiService instead of Python backend
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/commandes/${widget.commandeId}/track'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.token}',
        },
      );

      print('Tracking status: ${res.statusCode}');
      print('Tracking body: ${res.body}');

      if (res.statusCode == 404) {
        // ✅ Endpoint doesn't exist yet — show status from commande instead
        await _fetchCommandeStatus();
        return;
      }

      if (res.statusCode != 200) {
        setState(() { _error = 'Erreur serveur (${res.statusCode})'; _loading = false; });
        return;
      }

      final data = jsonDecode(res.body);
      _applyTrackingData(data);

    } catch (e) {
      // ✅ Fallback — just show commande status if tracking fails
      await _fetchCommandeStatus();
    }
  }

  // ✅ Fallback: get commande status from Node.js backend
  Future<void> _fetchCommandeStatus() async {
    try {
      final commandes = await ApiService.getMyCommandes();
      final commande = commandes.firstWhere(
            (c) => (c['_id'] ?? c['id']).toString() == widget.commandeId,
        orElse: () => {},
      );

      if (commande.isNotEmpty) {
        final status = commande['status'] ?? 'en attente';
        setState(() {
          _statut  = _mapStatus(status);
          _loading = false;
          _error   = null;
        });
      } else {
        setState(() {
          _loading = false;
          _statut  = 'en_attente';
        });
      }
    } catch (e) {
      setState(() {
        _error   = 'Connexion impossible';
        _loading = false;
      });
    }
  }

  void _applyTrackingData(Map<String, dynamic> data) {
    setState(() {
      _error   = null;
      _loading = false;
      _statut  = data['statut'] ?? 'en_attente';

      if (data['driver_lat'] != null && data['driver_lon'] != null) {
        _driverPos = LatLng(
          (data['driver_lat'] as num).toDouble(),
          (data['driver_lon'] as num).toDouble(),
        );
      }

      if (data['destination'] != null) {
        _destination = LatLng(
          (data['destination']['lat'] as num).toDouble(),
          (data['destination']['lon'] as num).toDouble(),
        );
      }

      _routePoints = ((data['route_points'] as List?) ?? [])
          .map((p) => LatLng(
        (p['lat'] as num).toDouble(),
        (p['lon'] as num).toDouble(),
      ))
          .toList();
    });

    if (_driverPos != null) {
      _mapController.move(_driverPos!, 14);
    } else if (_destination != null) {
      _mapController.move(_destination!, 13);
    }
  }

  // ✅ Map Node.js status to display status
  String _mapStatus(String status) {
    switch (status) {
      case 'en attente':   return 'en_attente';
      case 'en livraison': return 'assignee';
      case 'livrée':       return 'livree';
      case 'annulée':      return 'refusee';
      default:             return 'en_attente';
    }
  }

  Color get _statusColor {
    switch (_statut) {
      case 'en_attente': return Colors.orange;
      case 'acceptee':   return Colors.blue;
      case 'assignee':   return const Color(0xFF9C27B0);
      case 'livree':     return Colors.green;
      case 'refusee':    return Colors.red;
      default:           return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (_statut) {
      case 'en_attente': return '⏳ En attente de confirmation';
      case 'acceptee':   return '✅ Commande acceptée';
      case 'assignee':   return '🚚 Livreur en route';
      case 'livree':     return '🎉 Livraison effectuée !';
      case 'refusee':    return '❌ Commande refusée';
      default:           return _statut;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commande #${widget.commandeId.substring(0, 8)}...'),
        backgroundColor: const Color(0xFF0B3C49),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchTracking),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // ── Map ────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos ??
                  _destination ??
                  const LatLng(36.7538, 3.0588),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.yourapp',
              ),
              if (_routePoints.isNotEmpty || _driverPos != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [
                      if (_driverPos != null) _driverPos!,
                      ..._routePoints,
                      if (_destination != null) _destination!,
                    ],
                    color: const Color(0xFF0B3C49),
                    strokeWidth: 4,
                    isDotted: true,
                  ),
                ]),
              MarkerLayer(markers: [
                if (_driverPos != null)
                  Marker(
                    point: _driverPos!,
                    width: 50,
                    height: 50,
                    child: const Tooltip(
                      message: 'Votre livreur',
                      child: Icon(Icons.local_shipping,
                          color: Color(0xFF0B3C49), size: 40),
                    ),
                  ),
                if (_destination != null)
                  Marker(
                    point: _destination!,
                    width: 50,
                    height: 60,
                    child: Column(children: const [
                      Icon(Icons.home, color: Colors.green, size: 28),
                      Icon(Icons.location_pin, color: Colors.green, size: 24),
                    ]),
                  ),
              ]),
            ],
          ),

          // ── Status banner ──────────────────────────────
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Row(children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: _statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_statusLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14))),
                if (_statut == 'assignee')
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF9C27B0)),
                  ),
              ]),
            ),
          ),

          // ── Waiting message ────────────────────────────
          if (_driverPos == null &&
              (_statut == 'en_attente' || _statut == 'acceptee'))
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 12)
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _statut == 'en_attente'
                        ? Icons.hourglass_top
                        : Icons.check_circle_outline,
                    size: 52,
                    color: _statusColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statut == 'en_attente'
                        ? 'En attente d\'acceptation\npar le fournisseur'
                        : 'Commande acceptée.\nAssignation du livreur en cours...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                ]),
              ),
            ),

          // ── Error banner ───────────────────────────────
          if (_error != null)
            Positioned(
              bottom: 20, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.wifi_off,
                      color: Colors.deepOrange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.deepOrange, fontSize: 13))),
                  TextButton(
                    onPressed: _fetchTracking,
                    child: const Text('Réessayer',
                        style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}