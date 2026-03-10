import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'clientpage.dart';
import 'commandes.dart';
import 'historique.dart';
import 'profile.dart';

// ── API config ──────────────────────────────────────────────
const String _baseUrl = 'http://10.0.2.2:8000';

// One color per driver
const List<Color> _routeColors = [
  Color(0xFF2196F3), // Blue
  Color(0xFF4CAF50), // Green
  Color(0xFF9C27B0), // Purple
  Color(0xFFFF5722), // Orange
  Color(0xFF00BCD4), // Cyan
];

class suivi extends StatefulWidget {
  const suivi({super.key});

  @override
  State<suivi> createState() => _suiviState();
}

class _suiviState extends State<suivi> {
  final MapController mapController = MapController();

  // Map objects
  List<Polyline> _polylines = [];
  List<Marker>   _markers   = [];

  // State
  bool   _loadingRoutes = false;
  String? _routeError;
  double? _totalDistance;

  // GPS tracking
  Timer? _gpsTimer;
  LatLng? _myPosition;

  @override
  void initState() {
    super.initState();
    _loadSolution();
    _startGpsTracking();

    // Refresh routes every 30 seconds
    _gpsTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _loadSolution(),
    );
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  // ── Load optimized solution from API ─────────────────────

  Future<void> _loadSolution() async {
    setState(() { _loadingRoutes = true; _routeError = null; });

    // ── Fake test data in Algeria (El Harrach area) ──
    final data = {
      'total_distance_km': 12.5,
      'conducteurs': [
        {
          'id': 1,
          'nom': 'Conducteur A',
          'lat': 36.74851,   // El Harrach
          'lon': 2.94434,
          'capacity': 500,
          'route': [
            {
              'commande_id': 1,
              'description': 'Client 1 - Kouba',
              'lat': 36.76763,  // Kouba
              'lon': 3.03051,
            },
          ],
        },
        {
          'id': 2,
          'nom': 'Conducteur B',
          'lat': 36.7300,   // Belcourt
          'lon': 3.0700,
          'capacity': 2000,
          'route': [
            {
              'commande_id': 2,
              'description': 'Client 3 - Hussein Dey',
              'lat': 36.7400,  // Hussein Dey
              'lon': 3.1000,
            },
          ],
        },
        {
          'id': 1,
          'nom': 'Conducteur C',
          'lat': 36.6674,   // El Harrach
          'lon': 3.0961,
          'capacity': 1000,
          'route': [
            {
              'commande_id': 3,
              'description': 'Client 1 - alger',
              'lat': 36.7538,  // alger
              'lon': 3.0588,
            },
          ],
        },
      ],
    };

    _buildMapObjects(data);
    setState(() {
      _totalDistance = (data['total_distance_km'] as num).toDouble();
      _loadingRoutes = false;
    });
  }

  // ── Build polylines + markers from solution JSON ──────────

  void _buildMapObjects(Map<String, dynamic> solution) {
    final newPolylines = <Polyline>[];
    final newMarkers   = <Marker>[];
    final conducteurs  = solution['conducteurs'] as List<dynamic>;

    for (int i = 0; i < conducteurs.length; i++) {
      final c     = conducteurs[i];
      final color = _routeColors[i % _routeColors.length];
      final driverPos = LatLng(
        (c['lat'] as num).toDouble(),
        (c['lon'] as num).toDouble(),
      );

      // ── Driver marker ─────────────────────────────────────
      newMarkers.add(Marker(
        point: driverPos,
        width: 44,
        height: 44,
        child: Tooltip(
          message: '${c['nom']}\nCharge: ${c['load']}/${c['capacity']}',
          child: Icon(Icons.local_shipping, color: color, size: 36),
        ),
      ));

      // ── Route polyline ─────────────────────────────────────
      final route = c['route'] as List<dynamic>;
      if (route.isNotEmpty) {
        final points = <LatLng>[driverPos];
        for (final stop in route) {
          points.add(LatLng(
            (stop['lat'] as num).toDouble(),
            (stop['lon'] as num).toDouble(),
          ));
        }
        newPolylines.add(Polyline(
          points: points,
          color: color,
          strokeWidth: 4.0,
          isDotted: true,
        ));

        // ── Order markers ──────────────────────────────────
        for (int j = 0; j < route.length; j++) {
          final stop = route[j];
          final stopPos = LatLng(
            (stop['lat'] as num).toDouble(),
            (stop['lon'] as num).toDouble(),
          );
          newMarkers.add(Marker(
            point: stopPos,
            width: 40,
            height: 55,
            child: Tooltip(
              message: 'C${stop['commande_id']}: ${stop['description']}\n${stop['demand']} L',
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${j + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.location_pin, color: color, size: 30),
                ],
              ),
            ),
          ));
        }
      }
    }

    setState(() {
      _polylines = newPolylines;
      _markers   = newMarkers;
    });
  }

  // ── GPS: get user position and send to backend ────────────

  Future<void> _startGpsTracking() async {
    try {
      LocationPermission perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      // Update position every 10 seconds
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // only update if moved 10m
        ),
      ).listen((pos) async {
        setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));

        // Send to backend (change conducteur_id to match this driver)
        try {
          await http.post(
            Uri.parse('$_baseUrl/gps/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'conducteur_id': 1, // ← change per device/driver
              'lat': pos.latitude,
              'lon': pos.longitude,
            }),
          );
        } catch (_) {
          // Silently ignore network errors during tracking
        }
      });
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  void _goToMyLocation() async {
    if (_myPosition != null) {
      mapController.move(_myPosition!, 15);
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition();
        mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      } catch (_) {}
    }
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────
          FlutterMap(
            mapController: mapController,
            options: const MapOptions(
              initialCenter: LatLng(36.7538, 3.0588),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.yourapp',
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: [
                // My position marker
                if (_myPosition != null)
                  Marker(
                    point: _myPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.my_location,
                        color: Colors.blue, size: 36),
                  ),
                ..._markers,
              ]),
            ],
          ),

          // ── Loading indicator ─────────────────────────
          if (_loadingRoutes)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Chargement des routes...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Error banner ──────────────────────────────
          if (_routeError != null && !_loadingRoutes)
            Positioned(
              top: 60,
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
                    const Icon(Icons.info_outline,
                        color: Colors.deepOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_routeError!,
                            style: const TextStyle(
                                color: Colors.deepOrange, fontSize: 13))),
                    TextButton(
                      onPressed: _loadSolution,
                      child: const Text('Réessayer',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Distance summary ──────────────────────────
          if (_totalDistance != null)
            Positioned(
              top: 60,
              left: 16,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B3C49),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_totalDistance!.toStringAsFixed(1)} km total',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // ── My location button ─────────────────────────
          Positioned(
            bottom: 110,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location',
              backgroundColor: Colors.white,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, color: Color(0xFF0B3C49)),
            ),
          ),

          // ── Refresh routes button ──────────────────────
          Positioned(
            bottom: 160,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'refresh',
              backgroundColor: Colors.white,
              onPressed: _loadSolution,
              child: const Icon(Icons.refresh, color: Color(0xFF0B3C49)),
            ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0B3C49),
        shape: const CircleBorder(),
        child: const Icon(CupertinoIcons.home, color: Colors.white),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => clientpage()));
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom nav (unchanged) ─────────────────────────────
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8,
        height: 90,
        color: const Color(0xFF0B3C49),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.map,
                      color: Colors.white, size: 20),
                  onPressed: () {},
                ),
                const Text('suivi',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
              ],
            ),
            const SizedBox(width: 35),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.cube_box_fill,
                      color: Colors.white, size: 20),
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => commandes()));
                  },
                ),
                const Text('commandes',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(width: 25),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(CupertinoIcons.clock,
                      color: Colors.white, size: 20),
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => historique()));
                  },
                ),
                const Text('historique',
                    style: TextStyle(color: Colors.white, fontSize: 8)),
              ],
            ),
            const SizedBox(width: 22, height: 80),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.profile_circled,
                      color: Colors.white, size: 20),
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => profile()));
                  },
                ),
                const Text('profile',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}