import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'orders_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart'; // ✅ ApiService import

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({Key? key}) : super(key: key);

  @override
  State<ProviderHomeScreen> createState() => ProviderHomeScreenState();
}

class ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final MapController _mapController = MapController();

  bool   isOnline      = false;
  int    currentIndex  = 0;

  // ✅ Real GPS position instead of hardcoded LatLng
  LatLng _currentPosition = const LatLng(36.7538, 3.0588); // default Algiers
  bool   _gpsReady        = false;

  // ✅ Real capacity from backend instead of hardcoded 5400
  double _capacityLiters  = 0;
  bool   _loadingCapacity = true;

  List<Marker>  _markers      = [];
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

  // ── Load real capacity from backend ──────────────────────
  Future<void> _loadCapacity() async {
    setState(() => _loadingCapacity = true);
    try {
      // ✅ Load quantiteEau from fournisseurInfo, not chauffeur truck sizes
      final info = await ApiService.getMyInfo();
      final quantite = (info['fournisseurInfo']?['quantiteEau'] as num?)?.toDouble() ?? 0.0;
      setState(() {
        _capacityLiters  = quantite;
        _loadingCapacity = false;
      });
    } catch (e) {
      setState(() {
        _capacityLiters  = 0;
        _loadingCapacity = false;
      });
    }
  }

  // ── Real GPS tracking ─────────────────────────────────────
  Future<void> _startGps() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      // Get initial position
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _updatePosition(pos.latitude, pos.longitude);

      // Stream position updates
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) => _updatePosition(pos.latitude, pos.longitude));

      // ✅ Upload GPS to backend every 30s when online
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
      _markers = [
        Marker(
          point: _currentPosition,
          width: 80,
          height: 80,
          child: const Icon(
            Icons.local_shipping,
            color: Color(0xFF1E3A8A),
            size: 45,
          ),
        ),
      ];
    });
  }

  // ✅ Upload GPS position to backend via ApiService base URL
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
      // ✅ Use ApiService instead of raw http
      await ApiService.updatePosition(
        lat: _currentPosition.latitude,
        lon: _currentPosition.longitude,
      );
      _showSuccess('Vous êtes maintenant EN LIGNE — position enregistrée ✓');
    } else {
      // ✅ Use ApiService instead of raw http
      await ApiService.setOffline();
      _showSuccess('Vous êtes maintenant HORS LIGNE');
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
            initialCenter: _currentPosition,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.water_delivery_app',
            ),
            MarkerLayer(markers: _markers),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_shipping, color: Color(0xFF1E3A8A), size: 24),
                        const SizedBox(width: 8),
                        // ✅ Show real capacity from backend
                        _loadingCapacity
                            ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                          '${_capacityLiters.toStringAsFixed(0)} L',
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ]),
                    ),

                    // ✅ GPS indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: Icon(
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
                    blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnline ? 'VOUS ÊTES EN LIGNE' : 'VOUS ÊTES HORS LIGNE',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: isOnline ? Colors.green : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOnline
                            ? 'Vous recevez des commandes.'
                            : 'Vous ne recevez pas de commandes.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      // ✅ Show logged in fournisseur name
                      if (ApiService.userId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${ApiService.userId}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  )),
                  GestureDetector(
                    onTap: _toggleOnlineStatus,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Colors.red : const Color(0xFF1E3A8A),
                        boxShadow: [BoxShadow(
                          color: (isOnline ? Colors.red : const Color(0xFF1E3A8A))
                              .withOpacity(0.4),
                          blurRadius: 15, spreadRadius: 2,
                        )],
                      ),
                      child: Center(child: Text(
                        isOnline ? 'STOP' : 'GO',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22,
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
          BottomNavigationBarItem(icon: Icon(Icons.map),      label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Commandes'),
          BottomNavigationBarItem(icon: Icon(Icons.history),  label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.person),   label: 'Profil'),
        ],
      ),
    );
  }
}