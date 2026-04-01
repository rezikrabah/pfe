import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/osrmservice.dart';

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

  // Données de tracking
  String _statut = 'en_attente';
  LatLng? _driverPos;
  LatLng? _destination;
  List<LatLng> _routePoints = [];

  // Métriques de livraison
  double? _distanceKm;
  double? _durationMin;
  String? _driverName;
  String? _driverPhone;
  DateTime? _lastDriverUpdate;

  // État UI
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTracking();
    // Rafraîchissement toutes les 10 secondes
    _timer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _fetchTracking(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Récupère les données de tracking depuis le backend
  Future<void> _fetchTracking() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/commandes/${widget.commandeId}/track'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.token}',
        },
      );

      if (res.statusCode == 404) {
        await _fetchCommandeStatus();
        return;
      }

      if (res.statusCode != 200) {
        setState(() {
          _error = 'Erreur serveur (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body);
      await _applyTrackingData(data);

    } catch (e) {
      print('Erreur tracking: $e');
      await _fetchCommandeStatus();
    }
  }

  /// Fallback: récupère juste le statut si le endpoint /track échoue
  Future<void> _fetchCommandeStatus() async {
    try {
      final commandes = await ApiService.getMyCommandes();
      final commande = commandes.firstWhere(
            (c) => (c['_id'] ?? c['id']).toString() == widget.commandeId,
        orElse: () => {},
      );

      if (commande.isNotEmpty) {
        setState(() {
          _statut = _normalizeStatus(commande['status'] ?? 'en attente');
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _statut = 'en_attente';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connexion impossible';
        _loading = false;
      });
    }
  }

  /// Applique les données de tracking avec calcul de route OSRM
  Future<void> _applyTrackingData(Map<String, dynamic> data) async {
    print('TRACKING DATA COMPLET: ${jsonEncode(data)}');
    // ✅ Position chauffeur (format: data['driver']['lat'])
    LatLng? driverPos;
    if (data['driver_lat'] != null && data['driver_lon'] != null) {
      driverPos = LatLng(
        (data['driver_lat'] as num).toDouble(),
        (data['driver_lon'] as num).toDouble(),
      );
      _lastDriverUpdate = data['lastUpdate'] != null
          ? DateTime.tryParse(data['lastUpdate'])
          : null;
    }

    // ✅ Destination
    LatLng? destination;
    final dest = data['destination'];
    if (dest != null && dest['lat'] != null && dest['lon'] != null) {
      destination = LatLng(
        (dest['lat'] as num).toDouble(),
        (dest['lon'] as num).toDouble(),
      );
    }

    // ✅ Calcul de la route
    List<LatLng> routePoints = [];

    // Option 1: Route précalculée du backend (polyline)
    if (data['route'] != null && data['route'].toString().isNotEmpty) {
      routePoints = _decodePolyline(data['route']);
    }
    // Option 2: Calcul local avec OSRM (GeoJSON)
    else if (driverPos != null && destination != null) {
      try {
        routePoints = await OsrmService.getRoute(driverPos, destination);
      } catch (e) {
        print('OSRM local error: $e');
        routePoints = [driverPos, destination];
      }
    }

    // ✅ Métriques
    double? distanceKm;
    double? durationMin;

    if (data['estimatedDistance'] != null) {
      distanceKm = (data['estimatedDistance'] as num) / 1000;
    }
    if (data['estimatedDuration'] != null) {
      durationMin = (data['estimatedDuration'] as num) / 60;
    }

    // ✅ Infos chauffeur
    final chauffeur = data['chauffeur'];
    final driverName = chauffeur?['nom'];
    final driverPhone = chauffeur?['telephone'];

    setState(() {
      _error = null;
      _loading = false;
      _statut = _normalizeStatus(data['statut'] ?? 'en_attente');
      _driverPos = driverPos;
      _destination = destination;
      _routePoints = routePoints;
      _distanceKm = distanceKm;
      _durationMin = durationMin;
      _driverName = driverName;
      _driverPhone = driverPhone;
    });

    // Centrer la carte sur le chauffeur si disponible
    if (_driverPos != null) {
      _mapController.move(_driverPos!, 15);
    } else if (_destination != null) {
      _mapController.move(_destination!, 14);
    }
  }

  /// Décode une polyline encodée (format OSRM standard)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Normalise les statuts backend vers UI
  String _normalizeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'en attente':
        return 'en_attente';
      case 'en livraison':
        return 'assignee';
      case 'livrée':
        return 'livree';
      case 'annulée':
        return 'refusee';
      default:
        return 'en_attente';
    }
  }

  /// Couleur selon le statut
  Color get _statusColor {
    switch (_statut) {
      case 'en_attente':
        return Colors.orange;
      case 'acceptee':
        return Colors.blue;
      case 'assignee':
        return const Color(0xFF9C27B0);
      case 'livree':
        return Colors.green;
      case 'refusee':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Label lisible selon le statut
  String get _statusLabel {
    switch (_statut) {
      case 'en_attente':
        return '⏳ En attente de confirmation';
      case 'acceptee':
        return '✅ Commande acceptée';
      case 'assignee':
        return '🚚 Livreur en route';
      case 'livree':
        return '🎉 Livraison effectuée !';
      case 'refusee':
        return '❌ Commande refusée';
      default:
        return _statut;
    }
  }

  /// Formate le temps écoulé depuis la dernière position
  String? _getLastUpdateText() {
    if (_lastDriverUpdate == null) return null;
    final diff = DateTime.now().difference(_lastDriverUpdate!);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    return 'Il y a ${diff.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commande #${widget.commandeId.substring(0, 8)}...'),
        backgroundColor: const Color(0xFF0B3C49),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTracking,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // ── Carte ──────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos ??
                  _destination ??
                  const LatLng(36.7538, 3.0588),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.waterdelivery',
              ),

              // Route OSRM (ligne bleue)
              if (_routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF2979FF),
                      strokeWidth: 5,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Marqueurs
              MarkerLayer(
                markers: [
                  // Chauffeur (camion)
                  if (_driverPos != null)
                    Marker(
                      point: _driverPos!,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                  // Destination (client)
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 50,
                      height: 60,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 45,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Panel d'information ─────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statut
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_statut == 'assignee')
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF9C27B0),
                            ),
                          ),
                      ],
                    ),

                    // Info chauffeur
                    if (_driverName != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            radius: 18,
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driverName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_driverPhone != null)
                                  Text(
                                    _driverPhone!,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_driverPhone != null)
                            IconButton(
                              icon: const Icon(
                                Icons.phone,
                                color: Colors.green,
                              ),
                              onPressed: () {
                                // TODO: launchUrl(Uri.parse('tel:$_driverPhone'))
                              },
                            ),
                        ],
                      ),
                    ],

                    // Distance et temps estimé
                    if (_distanceKm != null && _durationMin != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.route,
                              value: '${_distanceKm!.toStringAsFixed(1)} km',
                              label: 'Distance',
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.access_time,
                              value: '${_durationMin!.round()} min',
                              label: 'Temps estimé',
                            ),
                          ),
                          if (_getLastUpdateText() != null) ...[
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            Expanded(
                              child: _buildMetricTile(
                                icon: Icons.update,
                                value: _getLastUpdateText()!,
                                label: 'Mise à jour',
                                iconColor: Colors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Message d'attente ────────────────────────────
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  ],
                ),
              ),
            ),

          // ── Boutons de contrôle ─────────────────────────
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centrer sur chauffeur
                if (_driverPos != null)
                  FloatingActionButton.small(
                    heroTag: 'center_driver',
                    onPressed: () {
                      _mapController.move(_driverPos!, 16);
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.red,
                    ),
                  ),
                if (_driverPos != null) const SizedBox(height: 8),

                // Centrer sur destination
                if (_destination != null)
                  FloatingActionButton.small(
                    heroTag: 'center_dest',
                    onPressed: () {
                      _mapController.move(_destination!, 16);
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                    ),
                  ),
                if (_destination != null) const SizedBox(height: 8),

                // Voir tout l'itinéraire
                FloatingActionButton(
                  heroTag: 'fit_bounds',
                  onPressed: () {
                    if (_driverPos != null && _destination != null) {
                      final bounds = LatLngBounds.fromPoints([
                        _driverPos!,
                        _destination!,
                      ]);
                      _mapController.fitBounds(
                        bounds,
                        options: const FitBoundsOptions(
                          padding: EdgeInsets.all(100),
                        ),
                      );
                    }
                  },
                  backgroundColor: const Color(0xFF0B3C49),
                  child: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),

          // ── Erreur ───────────────────────────────────────
          if (_error != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      color: Colors.deepOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchTracking,
                      child: const Text(
                        'Réessayer',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Widget helper pour les métriques (distance, temps, etc.)
  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}