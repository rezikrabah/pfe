import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'orders_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';
import '../services/osrmservice.dart'; // ✅ OSRM import

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({Key? key}) : super(key: key);

  @override
  State<ProviderHomeScreen> createState() => ProviderHomeScreenState();
}

class ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final MapController _mapController = MapController();

  bool   isOnline      = false;
  int    currentIndex  = 0;

  LatLng _currentPosition = const LatLng(36.76639 , 3.47717);
  bool   _gpsReady        = false;

  double _capacityLiters  = 0;
  bool   _loadingCapacity = true;

  // ✅ Route display
  List<Polyline> _polylines = [];
  List<Marker>   _markers   = [];
  bool           _loadingRoutes = false;

  StreamSubscription<Position>? _gpsSub;
  Timer?        _gpsUploadTimer;

  @override
  void initState() {
    super.initState();
    _loadCapacity();
    _startGps();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _gpsUploadTimer?.cancel();
    super.dispose();
  }

  // ── Load capacity ─────────────────────────────────────────
  Future<void> _loadCapacity() async {
    setState(() => _loadingCapacity = true);
    try {
      final info     = await ApiService.getMyInfo();
      final quantite = (info['fournisseurInfo']?['quantiteEau'] as num?)
          ?.toDouble() ?? 0.0;
      setState(() {
        _capacityLiters  = quantite;
        _loadingCapacity = false;
      });
    } catch (e) {
      setState(() { _capacityLiters = 0; _loadingCapacity = false; });
    }
  }

  // ── GPS ───────────────────────────────────────────────────
  Future<void> _startGps() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _updatePosition(pos.latitude, pos.longitude);

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) => _updatePosition(pos.latitude, pos.longitude));

      _gpsUploadTimer = Timer.periodic(
        const Duration(seconds: 30),
            (_) { if (isOnline) _uploadGps(); },
      );
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  void _updatePosition(double lat, double lon) {
    setState(() {
      _currentPosition = LatLng(lat, lon);
      _gpsReady        = true;
    });

    // ✅ Re-center map to real position when GPS first locks
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

  // ── Toggle GO/STOP ────────────────────────────────────────
  void _toggleOnlineStatus() async {
    final newStatus = !isOnline;
    setState(() => isOnline = newStatus);

    if (newStatus) {
      // ✅ Wait for real GPS position before going online
      if (!_gpsReady) {
        _showSuccess('Obtention du GPS...');
        // Wait up to 5 seconds for GPS
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
      setState(() { _polylines = []; _markers = []; });
      _showSuccess('Vous êtes maintenant HORS LIGNE');
    }
  }

  // ── Load OSRM routes fournisseur → s ────────────────
  Future<void> _loadAcceptedRoutes() async {
    setState(() => _loadingRoutes = true);
    try {
      // ✅ Get commandes assigned to this fournisseur that are en livraison
      final commandes = await ApiService.getCommandes(status: 'en livraison');

      final newPolylines = <Polyline>[];
      final newMarkers   = <Marker>[];

      // Always show fournisseur truck marker
      newMarkers.add(Marker(
        point: _currentPosition, width: 50, height: 50,
        child: const Icon(Icons.local_shipping,
            color: Color(0xFF1E3A8A), size: 42),
      ));

      for (int i = 0; i < commandes.length; i++) {
        final cmd      = commandes[i];
        final clientLat = (cmd['position']?['lat'] as num?)?.toDouble();
        final clientLon = (cmd['position']?['lon'] as num?)?.toDouble();
        print('CLIENT LAT: $clientLat LON: $clientLon');
        if (clientLat == null || clientLon == null) {
          print('❌ SKIPPING — no lat/lon on commande');
          continue;
        }
        final clientPos = LatLng(clientLat, clientLon);



        // ✅ OSRM real road route from fournisseur GPS to client
        final routePoints = await OsrmService.getRoute(
            _currentPosition, clientPos);
        final dist = await OsrmService.getDistanceAndDuration(
            _currentPosition, clientPos);

        final colors = [
          Colors.blue, Colors.green, Colors.purple,
          Colors.orange, Colors.teal
        ];
        final color = colors[i % colors.length];

        // Client marker
        final clientName = (cmd['client'] is Map)
            ? '${cmd['client']['prenom'] ?? ''} ${cmd['client']['nom'] ?? ''}'.trim()
            : 'Client';

        newMarkers.add(Marker(
          point: clientPos, width: 50, height: 60,
          child: Tooltip(
            message: '$clientName\n${dist['distance']?.toStringAsFixed(1)} km',
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(8)),
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Icon(Icons.home, color: color, size: 30),
            ]),
          ),
        ));

        // ✅ OSRM polyline
        newPolylines.add(Polyline(
          points:      routePoints,
          color:       color,
          strokeWidth: 4.0,
        ));
      }

      setState(() {
        _polylines     = newPolylines;
        _markers       = newMarkers;
        _loadingRoutes = false;
      });

      // Center map
      if (commandes.isNotEmpty) {
        _mapController.move(_currentPosition, 12);
      }
    } catch (e) {
      setState(() => _loadingRoutes = false);
      debugPrint('Route load error: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Map screen ────────────────────────────────────────────
  Widget _buildMapScreen() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _gpsReady
                ? _currentPosition
                : const LatLng(36.76639, 3.47717),
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.water_delivery_app',
            ),
            PolylineLayer(polylines: _polylines),
            MarkerLayer(markers: [
              // ✅ Live fournisseur position (blue dot)
              if (_gpsReady)
                Marker(
                  point: _currentPosition, width: 40, height: 40,
                  child: const Icon(Icons.my_location,
                      color: Colors.blue, size: 30),
                ),
              ..._markers,
            ]),
          ],
        ),

        // ── Header with capacity ──────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
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
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_shipping,
                            color: Color(0xFF1E3A8A), size: 24),
                        const SizedBox(width: 8),
                        _loadingCapacity
                            ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                            : Text('${_capacityLiters.toStringAsFixed(0)} L',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            )),
                      ]),
                    ),

                    // GPS + loading indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8)],
                      ),
                      child: _loadingRoutes
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.gps_fixed,
                          color: _gpsReady ? Colors.green : Colors.grey,
                          size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Recenter button ───────────────────────────────
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

        // ── Refresh routes button ─────────────────────────
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 160,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: isOnline ? _loadAcceptedRoutes : null,
            child: Icon(Icons.refresh,
                color: isOnline
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey),
          ),
        ),

        // ── Online / Offline status card ──────────────────
        Positioned(
          bottom: 80, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Column(
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
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (ApiService.userId != null) ...[
                        const SizedBox(height: 4),
                        Text('ID: ${ApiService.userId}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ],
                  )),
                  GestureDetector(
                    onTap: _toggleOnlineStatus,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? Colors.red
                            : const Color(0xFF1E3A8A),
                        boxShadow: [BoxShadow(
                          color: (isOnline
                              ? Colors.red
                              : const Color(0xFF1E3A8A))
                              .withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )],
                      ),
                      child: Center(child: Text(
                        isOnline ? 'STOP' : 'GO',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      )),
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
      body: IndexedStack(
        index: currentIndex,
        children: [
          _buildMapScreen(),
          const OrdersScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'Commandes'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}