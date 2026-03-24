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
import '../services/api_service.dart'; // ✅ Import ApiService

const List<Color> _routeColors = [
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFF9C27B0),
  Color(0xFFFF5722),
  Color(0xFF00BCD4),
];

class suivi extends StatefulWidget {
  final int? fournisseurId;
  const suivi({super.key, this.fournisseurId});

  @override
  State<suivi> createState() => _suiviState();
}

class _suiviState extends State<suivi> {
  final MapController mapController = MapController();

  List<Polyline> _polylines = [];
  List<Marker>   _markers   = [];
  bool           _loadingRoutes = false;
  String?        _routeError;
  double?        _totalDistance;

  Timer?  _refreshTimer;
  LatLng? _myPosition;

  @override
  void initState() {
    super.initState();
    _loadSolution();
    _startGpsTracking();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadSolution());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Load solution via ApiService ───────────────────────────
  Future<void> _loadSolution() async {
    setState(() { _loadingRoutes = true; _routeError = null; });

    try {
      // ✅ Use ApiService.optimiseRoute instead of raw http call
      final result = await ApiService.optimiseRoute({
        'fournisseurId': ApiService.userId,
      });

      if (result['error'] != null) {
        setState(() {
          _routeError    = result['error'];
          _loadingRoutes = false;
        });
      } else if (result['routes'] == null) {
        setState(() {
          _routeError    = 'Aucune solution calculée. Lancez l\'optimisation.';
          _loadingRoutes = false;
        });
      } else {
        _buildMapObjects(result);
        final routes = result['routes'] as List<dynamic>;
        double total = routes.fold(0.0, (sum, r) =>
        sum + ((r['distance_km'] as num?)?.toDouble() ?? 0.0));
        setState(() {
          _totalDistance = total;
          _loadingRoutes = false;
        });
      }
    } catch (e) {
      setState(() {
        _routeError    = 'Impossible de joindre le serveur.';
        _loadingRoutes = false;
      });
    }
  }

  // ── Build map from solution response ──────────────────────
  void _buildMapObjects(Map<String, dynamic> solution) async {
    final newPolylines = <Polyline>[];
    final newMarkers   = <Marker>[];

    try {
      // ✅ Use ApiService base URL for conductor and commande positions
      final condRes = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/chauffeurs/my'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.token}',
        },
      );

      final cmdRes = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/commandes?status=en livraison'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.token}',
        },
      );

      if (condRes.statusCode != 200 || cmdRes.statusCode != 200) return;

      final conducteurs = (jsonDecode(condRes.body) as List)
          .fold<Map<int, dynamic>>({}, (m, c) { m[c['id']] = c; return m; });
      final commandes = (jsonDecode(cmdRes.body) as List)
          .fold<Map<int, dynamic>>({}, (m, c) { m[c['id']] = c; return m; });

      final routes = solution['routes'] as List<dynamic>;

      for (int i = 0; i < routes.length; i++) {
        final r        = routes[i];
        final color    = _routeColors[i % _routeColors.length];
        final condId   = r['conducteur_id'] as int;
        final condData = conducteurs[condId];
        if (condData == null) continue;

        final driverPos = LatLng(
          (condData['lat'] as num).toDouble(),
          (condData['lon'] as num).toDouble(),
        );

        // Driver marker
        newMarkers.add(Marker(
          point: driverPos, width: 44, height: 44,
          child: Tooltip(
            message: '${r['conducteur_nom']}\n${r['charge']}/${r['capacite']} L',
            child: Icon(Icons.local_shipping, color: color, size: 36),
          ),
        ));

        // Route polyline + stop markers
        final stopIds = r['route'] as List<dynamic>;
        if (stopIds.isNotEmpty) {
          final points = <LatLng>[driverPos];
          for (int j = 0; j < stopIds.length; j++) {
            final cmd = commandes[stopIds[j]];
            if (cmd == null) continue;
            final stopPos = LatLng(
              (cmd['lat'] as num).toDouble(),
              (cmd['lon'] as num).toDouble(),
            );
            points.add(stopPos);

            newMarkers.add(Marker(
              point: stopPos, width: 40, height: 55,
              child: Tooltip(
                message: 'C${cmd['id']}: ${cmd['description']}',
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(8)),
                    child: Text('${j + 1}',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.location_pin, color: color, size: 30),
                ]),
              ),
            ));
          }
          newPolylines.add(Polyline(
              points: points, color: color, strokeWidth: 4.0, isDotted: true));
        }
      }

      setState(() {
        _polylines = newPolylines;
        _markers   = newMarkers;
      });
    } catch (e) {
      debugPrint('Map build error: $e');
    }
  }

  // ── GPS tracking ──────────────────────────────────────────
  Future<void> _startGpsTracking() async {
    try {
      LocationPermission perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) async {
        setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));
        try {
          // ✅ Use ApiService.baseUrl and token for GPS update
          await http.post(
            Uri.parse('${ApiService.baseUrl}/api/gps/update'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiService.token}',
            },
            body: jsonEncode({
              // ✅ Use ApiService.userId instead of hardcoded 1
              'conducteur_id': widget.fournisseurId ??
                  int.tryParse(ApiService.userId ?? '1') ?? 1,
              'lat': pos.latitude,
              'lon': pos.longitude,
            }),
          );
        } catch (_) {}
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
                urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.yourapp',
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: [
                if (_myPosition != null)
                  Marker(
                    point: _myPosition!, width: 40, height: 40,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 36),
                  ),
                ..._markers,
              ]),
            ],
          ),

          // ── Loading ────────────────────────────────────
          if (_loadingRoutes)
            Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Chargement des routes...', style: TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
            ),

          // ── Error ──────────────────────────────────────
          if (_routeError != null && !_loadingRoutes)
            Positioned(
              top: 60, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.deepOrange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_routeError!,
                      style: const TextStyle(color: Colors.deepOrange, fontSize: 13))),
                  TextButton(
                    onPressed: _loadSolution,
                    child: const Text('Réessayer', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ),

          // ── Distance badge ─────────────────────────────
          if (_totalDistance != null)
            Positioned(
              top: 60, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF0B3C49),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.route, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('${_totalDistance!.toStringAsFixed(1)} km total',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),

          // ── My location FAB ────────────────────────────
          Positioned(
            bottom: 110, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location', backgroundColor: Colors.white,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, color: Color(0xFF0B3C49)),
            ),
          ),

          // ── Refresh FAB ────────────────────────────────
          Positioned(
            bottom: 160, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'refresh', backgroundColor: Colors.white,
              onPressed: _loadSolution,
              child: const Icon(Icons.refresh, color: Color(0xFF0B3C49)),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0B3C49),
        shape: const CircleBorder(),
        child: const Icon(CupertinoIcons.home, color: Colors.white),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => clientpage())),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        notchMargin: 8, height: 90, color: const Color(0xFF0B3C49),
        child: Row(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(CupertinoIcons.map,
                    color: Colors.white, size: 20), onPressed: () {}),
                const Text('suivi', style: TextStyle(fontSize: 10, color: Colors.white)),
              ]),
          const SizedBox(width: 35),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.cube_box_fill, color: Colors.white, size: 20),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => commandes(
                        // ✅ Use ApiService.userId instead of hardcoded 1
                        clientId: int.tryParse(ApiService.userId ?? '1') ?? 1,
                      ))),
                ),
                const Text('commandes', style: TextStyle(fontSize: 8,
                    fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
          const SizedBox(width: 25),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  icon: const Icon(CupertinoIcons.clock, color: Colors.white, size: 20),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => historique())),
                ),
                const Text('historique', style: TextStyle(color: Colors.white, fontSize: 8)),
              ]),
          const SizedBox(width: 22, height: 80),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.profile_circled, color: Colors.white, size: 20),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => profile())),
                ),
                const Text('profile', style: TextStyle(color: Colors.white, fontSize: 10)),
              ]),
        ]),
      ),
    );
  }
}