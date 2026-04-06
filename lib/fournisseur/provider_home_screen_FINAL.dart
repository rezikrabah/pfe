import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'orders_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';
import '../services/osrmservice.dart';

class ProviderHomeScreen extends StatefulWidget {
  final bool isGerant;
  const ProviderHomeScreen({super.key, this.isGerant = false}); // false by default so normal chauffeurs aren't affected

  @override
  State<ProviderHomeScreen> createState() => ProviderHomeScreenState();
}

class ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _capacityController = TextEditingController();

  bool isOnline = false;
  int currentIndex = 0;

  LatLng _currentPosition = const LatLng(36.76639, 3.47717);
  bool _gpsReady = false;

  double _capacityLiters = 0;
  bool _loadingCapacity = true;

  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  bool _loadingRoutes = false;

  StreamSubscription<Position>? _gpsSub;
  Timer? _gpsUploadTimer;

  @override
  void initState() {
    super.initState();
    print('isGerant: ${widget.isGerant}'); // ← check your terminal\
    _loadCapacity();
    _startGps();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _gpsUploadTimer?.cancel();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadCapacity() async {
    setState(() => _loadingCapacity = true);
    try {
      final info = await ApiService.getMyInfo();
      final quantite =
          (info['fournisseurInfo']?['quantiteEau'] as num?)?.toDouble() ??
              0.0;

      if (!mounted) return;
      setState(() {
        _capacityLiters = quantite;
        _loadingCapacity = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capacityLiters = 0;
        _loadingCapacity = false;
      });
    }
  }

  Future<void> _showEditCapacityDialog() async {
    _capacityController.text = _capacityLiters.toStringAsFixed(0);

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier la quantité d’eau'),
          content: TextField(
            controller: _capacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^[0-9]*[.,]?[0-9]*$'),
              ),
            ],
            decoration: const InputDecoration(
              hintText: 'Entrez la quantité en litres',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = _capacityController.text.replaceAll(',', '.');
                final value = double.tryParse(text);
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final res = await ApiService.updateWaterQuantity(quantiteEau: result);

        if (res['error'] != null) {
          _showSuccess('Erreur serveur, quantité non enregistrée');
          return;
        }

        await _loadCapacity();
        _showSuccess('Quantité mise à jour avec succès');
      } catch (e) {
        _showSuccess('Erreur lors de la mise à jour');
      }
    }
  }

  Future<void> _startGps() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updatePosition(pos.latitude, pos.longitude);

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) => _updatePosition(pos.latitude, pos.longitude));

      _gpsUploadTimer = Timer.periodic(
        const Duration(seconds: 30),
            (_) {
          if (isOnline) _uploadGps();
        },
      );
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  void _updatePosition(double lat, double lon) {
    setState(() {
      _currentPosition = LatLng(lat, lon);
      _gpsReady = true;
    });

    if (isOnline) {
      _mapController.move(_currentPosition, 13.0);
    }
  }

  Future<void> _uploadGps() async {
    await ApiService.updatePosition(
      lat: _currentPosition.latitude,
      lon: _currentPosition.longitude,
    );
  }

  void _toggleOnlineStatus() async {
    final newStatus = !isOnline;
    setState(() => isOnline = newStatus);

    if (newStatus) {
      if (!_gpsReady) {
        _showSuccess('Obtention du GPS...');
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (_gpsReady) break;
        }
      }

      await ApiService.updatePosition(
        lat: _currentPosition.latitude,
        lon: _currentPosition.longitude,
      );
      _showSuccess('Vous êtes maintenant EN LIGNE ✓');
      await _loadAcceptedRoutes();
    } else {
      await ApiService.setOffline();
      setState(() {
        _polylines = [];
        _markers = [];
      });
      _showSuccess('Vous êtes maintenant HORS LIGNE');
    }
  }

  Future<void> _loadAcceptedRoutes() async {
    setState(() => _loadingRoutes = true);
    try {
      final commandes = await ApiService.getCommandes(status: 'en livraison');

      final newPolylines = <Polyline>[];
      final newMarkers = <Marker>[];

      newMarkers.add(
        Marker(
          point: _currentPosition,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: _showEditCapacityDialog,
            child: const Icon(
              Icons.local_shipping,
              color: Color(0xFF1E3A8A),
              size: 42,
            ),
          ),
        ),
      );

      for (int i = 0; i < commandes.length; i++) {
        final cmd = commandes[i];
        final clientLat = (cmd['position']?['lat'] as num?)?.toDouble();
        final clientLon = (cmd['position']?['lon'] as num?)?.toDouble();

        if (clientLat == null || clientLon == null) continue;

        final clientPos = LatLng(clientLat, clientLon);

        final routePoints = await OsrmService.getRoute(
          _currentPosition,
          clientPos,
        );
        final dist = await OsrmService.getDistanceAndDuration(
          _currentPosition,
          clientPos,
        );

        final colors = [
          Colors.blue,
          Colors.green,
          Colors.purple,
          Colors.orange,
          Colors.teal
        ];
        final color = colors[i % colors.length];

        final clientName = (cmd['client'] is Map)
            ? '${cmd['client']['prenom'] ?? ''} ${cmd['client']['nom'] ?? ''}'
            .trim()
            : 'Client';

        newMarkers.add(
          Marker(
            point: clientPos,
            width: 50,
            height: 60,
            child: Tooltip(
              message: '$clientName\n${dist['distance']?.toStringAsFixed(1)} km',
              child: Column(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.home, color: color, size: 30),
                ],
              ),
            ),
          ),
        );

        newPolylines.add(
          Polyline(
            points: routePoints,
            color: color,
            strokeWidth: 4.0,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _polylines = newPolylines;
        _markers = newMarkers;
        _loadingRoutes = false;
      });

      if (commandes.isNotEmpty) {
        _mapController.move(_currentPosition, 12);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoutes = false);
      debugPrint('Route load error: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMapScreen() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
            _gpsReady ? _currentPosition : const LatLng(36.76639, 3.47717),
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.water_delivery_app',
            ),
            PolylineLayer(polylines: _polylines),
            MarkerLayer(
              markers: [
                if (_gpsReady)
                  Marker(
                    point: _currentPosition,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ..._markers,
              ],
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_shipping,
                            color: Color(0xFF1E3A8A),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          _loadingCapacity
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            '${_capacityLiters.toStringAsFixed(0)} L',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showEditCapacityDialog,
                            child: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: _loadingRoutes
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(
                        Icons.gps_fixed,
                        color: _gpsReady ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 100,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => _mapController.move(_currentPosition, 13.0),
            child: const Icon(Icons.my_location, color: Color(0xFF1E3A8A)),
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 160,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: isOnline ? _loadAcceptedRoutes : null,
            child: Icon(
              Icons.refresh,
              color: isOnline ? const Color(0xFF1E3A8A) : Colors.grey,
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline
                              ? 'VOUS ÊTES EN LIGNE'
                              : 'VOUS ÊTES HORS LIGNE',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.green : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOnline
                              ? 'Routes affichées sur la carte.'
                              : 'Vous ne recevez pas de commandes.',
                          style:
                          TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        if (ApiService.userId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${ApiService.userId}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleOnlineStatus,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Colors.red : const Color(0xFF1E3A8A),
                        boxShadow: [
                          BoxShadow(
                            color: (isOnline
                                ? Colors.red
                                : const Color(0xFF1E3A8A))
                                .withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isOnline ? 'STOP' : 'GO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gerant banner ─────────────────────────────────
          if (widget.isGerant)
            SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: const Color(0xFF0B3C49),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text('Retourner au tableau de bord Gérant',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
                    ],
                  ),
                ),
              ),
            ),

          // ── Main content ───────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: [
                _buildMapScreen(),
                const OrdersScreen(),
                const HistoryScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E3A8A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Commandes'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}