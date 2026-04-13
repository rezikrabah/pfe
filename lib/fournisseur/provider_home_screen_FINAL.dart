import 'dart:async';
import 'dart:math' as dartMath;
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

// ─────────────────────────────────────────────────────────────────
// DEBUG HELPER
// All route-algorithm logs are prefixed [ROUTE] so you can filter
// them easily in the Flutter console:
//   flutter logs | grep '\[ROUTE\]'
// ─────────────────────────────────────────────────────────────────
void _log(String msg) => debugPrint('[ROUTE] $msg');

class ProviderHomeScreen extends StatefulWidget {
  final bool    isGerant;
  final bool    startOnline;
  final String? activeCommandeId;
  final double? destinationLat;
  final double? destinationLon;
  final List<Map<String, dynamic>> testOrders;

  const ProviderHomeScreen({
    super.key,
    this.isGerant        = false,
    this.startOnline     = false,
    this.activeCommandeId,
    this.destinationLat,
    this.destinationLon,
    this.testOrders      = const [],
  });

  @override
  State<ProviderHomeScreen> createState() => ProviderHomeScreenState();
}

class ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final MapController         _mapController      = MapController();
  final TextEditingController _capacityController = TextEditingController();

  bool isOnline     = false;
  int  currentIndex = 0;

  LatLng _currentPosition = const LatLng(36.76639, 3.47717);
  bool   _gpsReady        = false;

  double _capacityLiters  = 0;
  bool   _loadingCapacity = true;

  List<Polyline> _polylines     = [];
  List<Marker>   _markers       = [];
  bool           _loadingRoutes = false;

  List<_RouteStop> _optimizedStops = [];
  double?          _totalDistanceKm;
  bool             _routeIsValid   = false;

  List<Map<String, dynamic>> _testOrders = [];

  StreamSubscription<Position>? _gpsSub;
  Timer?                        _gpsUploadTimer;

  // ── Simulation state ────────────────────────────────────────────
  List<LatLng> _fullRoutePoints = [];
  int  _simIndex   = 0;
  bool _simRunning = false;
  bool _simStarted = false;
  LatLng? _simPosition;

  static const int      _simStepSize = 3;
  static const Duration _simInterval = Duration(milliseconds: 100);

  Timer? _simTimer;

  int  _currentStopTarget    = 0;
  bool _arrivalDialogShowing = false;
  int  _simUploadCounter     = 0;
  static const int _uploadEveryNTicks = 10;

  // ─────────────────────────────────────────────────────────
  // INIT / DISPOSE
  // ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.testOrders.isNotEmpty) {
      _testOrders = List<Map<String, dynamic>>.from(widget.testOrders);
      _log('initState: ${_testOrders.length} test orders loaded from widget');
    }
    _loadCapacity();
    _startGps();
    if (widget.startOnline) _waitForGpsAndGoOnline();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _gpsSub?.cancel();
    _gpsUploadTimer?.cancel();
    _capacityController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC — called by OrdersScreen after accepting a commande
  // ─────────────────────────────────────────────────────────
  void goToMapWithRoute({
    required String  commandeId,
    required double? destLat,
    required double? destLon,
    List<Map<String, dynamic>>? testOrders,
  }) {
    _log('goToMapWithRoute: commandeId=$commandeId  testOrders=${testOrders?.length ?? 0}');
    setState(() {
      currentIndex = 0;
      if (testOrders != null && testOrders.isNotEmpty) {
        _testOrders = List<Map<String, dynamic>>.from(testOrders);
        _log('goToMapWithRoute: stored ${_testOrders.length} test orders → will use NN (no API)');
      } else {
        _log('goToMapWithRoute: no testOrders → will use real API + VRP/NN');
      }
    });
    if (!isOnline) {
      setState(() => isOnline = true);
      ApiService.updatePosition(
        lat: _currentPosition.latitude,
        lon: _currentPosition.longitude,
      );
    }
    _loadOptimizedRoutes();
  }

  // ─────────────────────────────────────────────────────────
  // GPS
  // ─────────────────────────────────────────────────────────

  Future<void> _waitForGpsAndGoOnline() async {
    _showSnack('Initialisation du GPS...', Colors.blue);
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_gpsReady) break;
    }
    if (!mounted) return;
    if (_gpsReady) {
      setState(() => isOnline = true);
      await ApiService.updatePosition(
        lat: _currentPosition.latitude,
        lon: _currentPosition.longitude,
      );
      _showSnack('Vous êtes maintenant EN LIGNE ✓', Colors.green);
      await _loadOptimizedRoutes();
    } else {
      _showSnack('GPS non disponible', Colors.orange);
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
          desiredAccuracy: LocationAccuracy.high);
      _updatePosition(pos.latitude, pos.longitude);

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy:       LocationAccuracy.high,
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
    if (isOnline) _mapController.move(_currentPosition, 13.0);
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
        _showSnack('Obtention du GPS...', Colors.blue);
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (_gpsReady) break;
        }
      }
      await ApiService.updatePosition(
        lat: _currentPosition.latitude,
        lon: _currentPosition.longitude,
      );
      _showSnack('Vous êtes maintenant EN LIGNE ✓', Colors.green);
      await _loadOptimizedRoutes();
    } else {
      await ApiService.setOffline();
      _stopSimulation();
      setState(() {
        _polylines        = [];
        _markers          = [];
        _optimizedStops   = [];
        _totalDistanceKm  = null;
        _testOrders       = [];
        _fullRoutePoints  = [];
      });
      _showSnack('Vous êtes maintenant HORS LIGNE', Colors.grey);
    }
  }

  // ─────────────────────────────────────────────────────────
  // SIMULATION CONTROLS
  // ─────────────────────────────────────────────────────────

  void _startSimulation({bool resume = false}) {
    if (_fullRoutePoints.isEmpty) {
      _showSnack('Aucun itinéraire disponible pour la simulation', Colors.orange);
      return;
    }
    setState(() {
      _simRunning = true;
      _simStarted = true;
      if (!resume) {
        _simIndex          = 0;
        _simPosition       = _fullRoutePoints.first;
        _currentStopTarget = 0;
      }
    });

    _simTimer?.cancel();
    _simTimer = Timer.periodic(_simInterval, (_) async {
      if (!mounted) { _simTimer?.cancel(); return; }

      if (_simIndex >= _fullRoutePoints.length - 1) {
        _simTimer?.cancel();
        setState(() {
          _simRunning  = false;
          _simPosition = _fullRoutePoints.last;
        });
        _showSnack('Simulation terminée ✓', Colors.green);
        return;
      }

      setState(() {
        _simIndex    = (_simIndex + _simStepSize)
            .clamp(0, _fullRoutePoints.length - 1);
        _simPosition = _fullRoutePoints[_simIndex];
      });

      _simUploadCounter++;
      if (_simUploadCounter >= _uploadEveryNTicks) {
        _simUploadCounter = 0;
        ApiService.updatePosition(
          lat: _simPosition!.latitude,
          lon: _simPosition!.longitude,
        );
      }

      if (!_arrivalDialogShowing &&
          _currentStopTarget < _optimizedStops.length) {
        final stop = _optimizedStops[_currentStopTarget];
        final dist = _haversineKmStatic(
          _simPosition!.latitude,  _simPosition!.longitude,
          stop.position.latitude,  stop.position.longitude,
        ) * 1000;

        if (dist < 50) {
          _arrivalDialogShowing = true;
          _simTimer?.cancel();
          await _showDeliveryCompletionDialog(stop);
        }
      }
    });
  }

  Future<void> _showDeliveryCompletionDialog(_RouteStop stop) async {
    final priceController = TextEditingController(
      text: stop.quantity > 0 ? stop.quantity.toStringAsFixed(0) : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arrivée chez le client',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(stop.clientName,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stop.address.isNotEmpty) ...[
              Row(children: [
                Icon(Icons.place, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(stop.address,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ),
              ]),
              const SizedBox(height: 16),
            ],
            const Text('Montant à encaisser (DA)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller:   priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixIcon:  const Icon(Icons.payments_outlined),
                hintText:    'Ex: 1500',
                suffixText:  'DA',
                filled:      true,
                fillColor:   Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon:  const Icon(Icons.check_circle_outline),
            label: const Text('Confirmer la livraison'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.updateCommandeStatus(
          commandeId: stop.mongoId,
          status:     'livrée',
          prix:       double.tryParse(
              priceController.text.replaceAll(',', '.')),
        );
        _showSnack('Livraison confirmée ✓', Colors.green);

        setState(() {
          _currentStopTarget++;
          _arrivalDialogShowing = false;
        });

        if (_currentStopTarget < _optimizedStops.length) {
          _startSimulation(resume: true);
        } else {
          _showSnack('Toutes les livraisons sont terminées ', Colors.green);
        }
      } catch (e) {
        _showSnack('Erreur lors de la confirmation', Colors.red);
        setState(() => _arrivalDialogShowing = false);
        _startSimulation(resume: true);
      }
    } else {
      setState(() => _arrivalDialogShowing = false);
      _startSimulation(resume: true);
    }

    priceController.dispose();
  }

  void _pauseSimulation() {
    _simTimer?.cancel();
    setState(() => _simRunning = false);
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    setState(() {
      _simRunning           = false;
      _simStarted           = false;
      _simIndex             = 0;
      _simPosition          = null;
      _currentStopTarget    = 0;
      _arrivalDialogShowing = false;
      _simUploadCounter     = 0;
    });
  }

  // ─────────────────────────────────────────────────────────
  // CORE: decide test data vs real API
  // ─────────────────────────────────────────────────────────
  Future<void> _loadOptimizedRoutes() async {
    _stopSimulation();

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('_loadOptimizedRoutes called');
    _log('  testOrders count : ${_testOrders.length}');
    _log('  currentPosition  : ${_currentPosition.latitude.toStringAsFixed(5)}, '
        '${_currentPosition.longitude.toStringAsFixed(5)}');

    if (_testOrders.isNotEmpty) {
      _log('  → MODE: TEST (nearest-neighbour, no API)');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await _buildRouteFromTestOrders();
      return;
    }

    _log('  → MODE: REAL API (VRP/NSGA-II or NN fallback)');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    await _loadOptimizedRoutesFromApi();
  }

  // ─────────────────────────────────────────────────────────
  // NEAREST-NEIGHBOUR GREEDY SORT
  // ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _nearestNeighbourSort(
      LatLng startPosition,
      List<Map<String, dynamic>> orders,
      ) {
    _log('  NN sort: ${orders.length} orders, start=(${startPosition.latitude.toStringAsFixed(4)}, '
        '${startPosition.longitude.toStringAsFixed(4)})');

    if (orders.isEmpty) return [];

    final unvisited = List<Map<String, dynamic>>.from(orders);
    final sorted    = <Map<String, dynamic>>[];
    double curLat   = startPosition.latitude;
    double curLon   = startPosition.longitude;
    int    step     = 0;

    while (unvisited.isNotEmpty) {
      int    bestIdx  = 0;
      double bestDist = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final lat = (unvisited[i]['lat'] as num?)?.toDouble();
        final lon = (unvisited[i]['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final d = _haversineKmStatic(curLat, curLon, lat, lon);
        if (d < bestDist) {
          bestDist = d;
          bestIdx  = i;
        }
      }

      final chosen = unvisited.removeAt(bestIdx);
      sorted.add(chosen);

      // Print each hop so you can verify the order makes geographic sense
      final chosenLat = (chosen['lat'] as num?)?.toDouble() ?? curLat;
      final chosenLon = (chosen['lon'] as num?)?.toDouble() ?? curLon;
      final label     = chosen['clientName']
          ?? chosen['_mongoId']
          ?? chosen['id']
          ?? 'stop${step + 1}';
      _log('    step ${step + 1}: $label  dist=${bestDist.toStringAsFixed(2)} km'
          '  pos=(${chosenLat.toStringAsFixed(4)}, ${chosenLon.toStringAsFixed(4)})');

      curLat = chosenLat;
      curLon = chosenLon;
      step++;
    }

    return sorted;
  }

  static double _haversineKmStatic(
      double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371.0;
    const pi   = 3.141592653589793;
    final dlat = (lat2 - lat1) * pi / 180.0;
    final dlon = (lon2 - lon1) * pi / 180.0;
    final sinD = _dartSin(dlat / 2);
    final sinL = _dartSin(dlon / 2);
    final a    = sinD * sinD +
        _dartCos(lat1 * pi / 180.0) *
            _dartCos(lat2 * pi / 180.0) *
            sinL * sinL;
    return r * 2 * _dartAsin(_dartSqrt(a < 0 ? 0 : a));
  }

  static double _dartSin(double x)  => dartMath.sin(x);
  static double _dartCos(double x)  => dartMath.cos(x);
  static double _dartAsin(double x) => dartMath.asin(x);
  static double _dartSqrt(double x) => dartMath.sqrt(x);

  // ─────────────────────────────────────────────────────────
  // TEST MODE: nearest-neighbour on local test orders
  // ─────────────────────────────────────────────────────────
  Future<void> _buildRouteFromTestOrders() async {
    setState(() => _loadingRoutes = true);
    try {
      final acceptedOrders = _testOrders
          .where((o) =>
      o['status'] == 'accepted' || o['status'] == 'en livraison')
          .toList();

      final rawOrders =
      acceptedOrders.isNotEmpty ? acceptedOrders : _testOrders;

      _log('TEST MODE: ${rawOrders.length} orders to route'
          ' (${acceptedOrders.length} accepted, ${_testOrders.length} total)');
      for (int i = 0; i < rawOrders.length; i++) {
        final o = rawOrders[i];
        _log('  [${i + 1}] id=${o['id']}  name=${o['clientName']}'
            '  status=${o['status']}'
            '  lat=${o['lat']}  lon=${o['lon']}');
      }

      _log('  Running nearest-neighbour sort...');
      final ordersToRoute = _nearestNeighbourSort(_currentPosition, rawOrders);

      final List<LatLng>     waypoints = [_currentPosition];
      final List<_RouteStop> stops     = [];

      for (int i = 0; i < ordersToRoute.length; i++) {
        final o   = ordersToRoute[i];
        final lat = (o['lat'] as num?)?.toDouble();
        final lon = (o['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) {
          _log('  WARNING: stop $i has null lat/lon — skipped');
          continue;
        }

        waypoints.add(LatLng(lat, lon));
        stops.add(_RouteStop(
          index:      i + 1,
          mongoId:    o['id'].toString(),
          clientName: o['clientName'] ?? 'Client ${i + 1}',
          position:   LatLng(lat, lon),
          address:    o['address'] ?? '',
          quantity:   (o['quantity'] as num?)?.toDouble() ?? 0,
        ));
      }

      _log('TEST MODE: calling OSRM for ${waypoints.length - 1} road segments...');

      final List<LatLng> fullRoutePoints = [];
      double totalDist = 0;
      final List<double> legDist = [];
      final List<double> legDur  = [];

      for (int i = 0; i < waypoints.length - 1; i++) {
        final result = await OsrmService.getRouteWithMetrics(
            waypoints[i], waypoints[i + 1]);
        final pts = result['points'] as List<LatLng>;
        final d   = result['distanceKm']  as double? ?? 0;
        final dur = result['durationMin'] as double? ?? 0;

        _log('  OSRM leg $i→${i + 1}: ${d.toStringAsFixed(2)} km  ${dur.toStringAsFixed(1)} min  (${pts.length} pts)');

        if (fullRoutePoints.isNotEmpty && pts.isNotEmpty) {
          fullRoutePoints.addAll(pts.skip(1));
        } else {
          fullRoutePoints.addAll(pts);
        }
        totalDist += d;
        legDist.add(d);
        legDur.add(dur);
      }

      final List<_RouteStop> enrichedStops = List<_RouteStop>.from(stops);
      for (int i = 0; i < enrichedStops.length && i < legDist.length; i++) {
        enrichedStops[i] = enrichedStops[i].copyWith(
          distanceKm:  legDist[i],
          durationMin: legDur[i],
        );
      }

      _log('TEST MODE: route built — total ${totalDist.toStringAsFixed(2)} km'
          '  ${fullRoutePoints.length} polyline points');

      final List<Polyline> newPolylines = [];
      if (fullRoutePoints.length > 1) {
        newPolylines.add(Polyline(
          points:            fullRoutePoints,
          color:             const Color(0xFF1565C0),
          strokeWidth:       5,
          borderStrokeWidth: 2,
          borderColor:       Colors.white,
        ));
      }

      if (!mounted) return;
      setState(() {
        _polylines       = newPolylines;
        _markers         = _buildMarkers(enrichedStops);
        _optimizedStops  = enrichedStops;
        _totalDistanceKm = totalDist;
        _routeIsValid    = true;
        _loadingRoutes   = false;
        _fullRoutePoints = List<LatLng>.from(fullRoutePoints);
      });

      if (waypoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(waypoints);
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(
              padding: EdgeInsets.fromLTRB(40, 120, 40, 300)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoutes = false);
      _log('TEST MODE ERROR: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // REAL MODE: VRP solution from API, NN fallback
  // ─────────────────────────────────────────────────────────
  Future<void> _loadOptimizedRoutesFromApi() async {
    setState(() => _loadingRoutes = true);

    try {
      _log('REAL MODE: fetching commandes (status=en livraison)...');
      final commandes = await ApiService.getCommandes(status: 'en livraison');
      _log('REAL MODE: ${commandes.length} commandes found');

      if (commandes.isEmpty) {
        _log('REAL MODE: no commandes → clearing map');
        setState(() {
          _polylines       = [];
          _markers         = [];
          _optimizedStops  = [];
          _totalDistanceKm = null;
          _loadingRoutes   = false;
          _fullRoutePoints = [];
        });
        _mapController.move(_currentPosition, 13);
        return;
      }

      // Log each commande so we can verify vrpId mapping
      for (final c in commandes) {
        final mongoId = (c['_id'] ?? c['id']).toString();
        final vrpId   = c['vrpId']?.toString() ?? 'NULL';
        final lat     = c['position']?['lat'];
        final lon     = c['position']?['lon'];
        _log('  commande mongoId=$mongoId  vrpId=$vrpId  lat=$lat  lon=$lon');
      }

      final Map<String, Map<String, dynamic>> commandeById = {
        for (final c in commandes)
          (c['_id'] ?? c['id']).toString(): c,
      };

      _log('REAL MODE: calling getVrpSolution()...');
      final vrpResult = await ApiService.getVrpSolution();

      // Log the raw VRP response so you can see what Python returned
      _log('REAL MODE: VRP response keys = ${vrpResult.keys.toList()}');
      if (vrpResult['error'] != null) {
        _log('  VRP error field: ${vrpResult['error']}');
      }
      if (vrpResult['routes'] != null) {
        final routes = vrpResult['routes'] as List;
        _log('  VRP routes count: ${routes.length}');
        for (int ri = 0; ri < routes.length; ri++) {
          final r = routes[ri];
          _log('    route[$ri] conducteur_id=${r['conducteur_id']}  '
              'route=${r['route']}  distance_km=${r['distance_km']}');
        }
        _log('  VRP distance_totale_km=${vrpResult['distance_totale_km']}');
        _log('  VRP valide=${vrpResult['valide']}');
        _log('  VRP nb_commandes=${vrpResult['nb_commandes']}');
      } else {
        _log('  VRP routes = null');
      }

      List<String> orderedMongoIds = [];
      bool usedVrp = false;

      if (vrpResult['error'] == null && vrpResult['routes'] != null) {
        final routes = vrpResult['routes'] as List;
        _totalDistanceKm =
            (vrpResult['distance_totale_km'] as num?)?.toDouble();
        _routeIsValid = vrpResult['valide'] as bool? ?? false;

        final Map<String, String> vrpToMongo = {};
        for (final c in commandes) {
          final mongoId = (c['_id'] ?? c['id']).toString();
          final vrpId   = c['vrpId']?.toString();
          if (vrpId != null) vrpToMongo[vrpId] = mongoId;
        }
        _log('  vrpId→mongoId map: $vrpToMongo');

        for (final routeObj in routes) {
          final vrpIds = (routeObj['route'] as List?) ?? [];
          for (final vid in vrpIds) {
            final mongoId = vrpToMongo[vid.toString()];
            if (mongoId != null) {
              orderedMongoIds.add(mongoId);
            } else {
              _log('  WARNING: vrpId $vid has no matching mongoId — skipped');
            }
          }
        }

        if (orderedMongoIds.isNotEmpty) {
          usedVrp = true;
          _log('REAL MODE: ✅ NSGA-II solution used — '
              '${orderedMongoIds.length} stops ordered by Python VRP');
          _log('  NSGA-II stop order: $orderedMongoIds');
        } else {
          _log('REAL MODE: ⚠️ VRP routes were non-empty but vrpId mapping '
              'produced 0 mongoIds → falling back to NN');
        }
      } else {
        _log('REAL MODE: ⚠️ VRP unavailable or error → will use NN fallback');
      }

      // ── FALLBACK: nearest-neighbour ──────────────────────────
      if (!usedVrp) {
        _totalDistanceKm = null;
        _routeIsValid    = false;

        _log('REAL MODE: 🔄 nearest-neighbour fallback on ${commandeById.length} commandes');

        final flatList = commandeById.entries
            .map((e) {
          final lat = (e.value['position']?['lat'] as num?)?.toDouble();
          final lon = (e.value['position']?['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) {
            _log('  WARNING: commande ${e.key} has null position — excluded from NN');
            return null;
          }
          return <String, dynamic>{
            '_mongoId':    e.key,
            'lat':         lat,
            'lon':         lon,
            'clientName':  (e.value['client'] is Map)
                ? '${e.value['client']['prenom'] ?? ''} ${e.value['client']['nom'] ?? ''}'.trim()
                : e.key,
          };
        })
            .whereType<Map<String, dynamic>>()
            .toList();

        _log('  NN input: ${flatList.length} valid positions');
        final sorted = _nearestNeighbourSort(_currentPosition, flatList);
        orderedMongoIds = sorted.map((o) => o['_mongoId'].toString()).toList();
        _log('  NN result order: $orderedMongoIds');
      }

      // ── Build waypoints ──────────────────────────────────────
      _log('REAL MODE: building waypoints from ${orderedMongoIds.length} ordered IDs...');
      final List<LatLng>     waypoints = [_currentPosition];
      final List<_RouteStop> stops     = [];

      for (int i = 0; i < orderedMongoIds.length; i++) {
        final id  = orderedMongoIds[i];
        final cmd = commandeById[id];
        if (cmd == null) {
          _log('  WARNING: mongoId $id not in commandeById — skipped');
          continue;
        }

        final lat = (cmd['position']?['lat'] as num?)?.toDouble();
        final lon = (cmd['position']?['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) {
          _log('  WARNING: commande $id has null position — skipped');
          continue;
        }

        final raw = cmd['client'];
        final clientName = (raw is Map)
            ? '${raw['prenom'] ?? ''} ${raw['nom'] ?? ''}'.trim()
            : 'Client ${i + 1}';

        _log('  stop ${i + 1}: $clientName  ($lat, $lon)');
        waypoints.add(LatLng(lat, lon));
        stops.add(_RouteStop(
          index:      i + 1,
          mongoId:    id,
          clientName: clientName.isEmpty ? 'Client ${i + 1}' : clientName,
          position:   LatLng(lat, lon),
          address:    cmd['adresse'] ?? '',
          quantity:   (cmd['capacite'] as num?)?.toDouble() ?? 0,
        ));
      }

      // ── OSRM road segments ───────────────────────────────────
      _log('REAL MODE: calling OSRM for ${waypoints.length - 1} road segments...');
      final List<LatLng> fullRoutePoints = [];
      double segmentDistKm = 0;
      final List<double> legDistances = [];
      final List<double> legDurations = [];

      for (int i = 0; i < waypoints.length - 1; i++) {
        final result = await OsrmService.getRouteWithMetrics(
            waypoints[i], waypoints[i + 1]);
        final pts = result['points'] as List<LatLng>;
        final d   = result['distanceKm']  as double? ?? 0;
        final dur = result['durationMin'] as double? ?? 0;

        _log('  OSRM leg $i→${i + 1}: ${d.toStringAsFixed(2)} km  ${dur.toStringAsFixed(1)} min');

        if (fullRoutePoints.isNotEmpty && pts.isNotEmpty) {
          fullRoutePoints.addAll(pts.skip(1));
        } else {
          fullRoutePoints.addAll(pts);
        }
        segmentDistKm += d;
        legDistances.add(d);
        legDurations.add(dur);
      }

      for (int i = 0; i < stops.length && i < legDistances.length; i++) {
        stops[i] = stops[i].copyWith(
          distanceKm:  legDistances[i],
          durationMin: legDurations[i],
        );
      }

      final usedAlgo = usedVrp ? 'NSGA-II (Python VRP)' : 'Nearest-Neighbour (fallback)';
      _log('REAL MODE: ✅ route complete — algorithm=$usedAlgo'
          '  total=${segmentDistKm.toStringAsFixed(2)} km'
          '  stops=${stops.length}'
          '  polyline_pts=${fullRoutePoints.length}');

      final List<Polyline> newPolylines = [];
      if (fullRoutePoints.length > 1) {
        newPolylines.add(Polyline(
          points:            fullRoutePoints,
          color:             const Color(0xFF1565C0),
          strokeWidth:       5,
          borderStrokeWidth: 2,
          borderColor:       Colors.white,
        ));
      }

      if (!mounted) return;
      setState(() {
        _polylines        = newPolylines;
        _markers          = _buildMarkers(stops);
        _optimizedStops   = stops;
        _totalDistanceKm  = _totalDistanceKm ?? segmentDistKm;
        _loadingRoutes    = false;
        _fullRoutePoints  = List<LatLng>.from(fullRoutePoints);
      });

      if (waypoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(waypoints);
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(
              padding: EdgeInsets.fromLTRB(40, 120, 40, 300)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoutes = false);
      _log('REAL MODE ERROR: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // SHARED MARKER BUILDER
  // ─────────────────────────────────────────────────────────
  List<Marker> _buildMarkers(List<_RouteStop> stops) {
    final stopColors = [
      Colors.blue, Colors.green, Colors.purple,
      Colors.orange, Colors.teal, Colors.red,
    ];

    final List<Marker> markers = [
      Marker(
        point:  _currentPosition,
        width:  56,
        height: 56,
        child: GestureDetector(
          onTap: _showEditCapacityDialog,
          child: Container(
            decoration: BoxDecoration(
              color:  const Color(0xFF1E3A8A),
              shape:  BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.local_shipping,
                color: Colors.white, size: 28),
          ),
        ),
      ),
    ];

    for (int i = 0; i < stops.length; i++) {
      final stop  = stops[i];
      final color = stopColors[i % stopColors.length];
      markers.add(Marker(
        point:  stop.position,
        width:  72,
        height: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Text(
                stop.distanceKm != null
                    ? '${stop.index}. ${stop.distanceKm!.toStringAsFixed(1)} km\n'
                    '${stop.durationMin?.round()} min'
                    : '${stop.index}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   9,
                  fontWeight: FontWeight.bold,
                  height:     1.3,
                ),
              ),
            ),
            Icon(Icons.location_on, color: color, size: 32),
          ],
        ),
      ));
    }
    return markers;
  }

  // ─────────────────────────────────────────────────────────
  // CAPACITY
  // ─────────────────────────────────────────────────────────

  Future<void> _loadCapacity() async {
    setState(() => _loadingCapacity = true);
    try {
      final info     = await ApiService.getMyInfo();
      final quantite =
          (info['fournisseurInfo']?['quantiteEau'] as num?)?.toDouble() ?? 0.0;
      if (!mounted) return;
      setState(() { _capacityLiters = quantite; _loadingCapacity = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _capacityLiters = 0; _loadingCapacity = false; });
    }
  }

  Future<void> _showEditCapacityDialog() async {
    _capacityController.text = _capacityLiters.toStringAsFixed(0);
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la quantité d\'eau'),
        content: TextField(
          controller:   _capacityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^[0-9]*[.,]?[0-9]*$')),
          ],
          decoration: const InputDecoration(
              hintText: 'Entrez la quantité en litres'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(
                  _capacityController.text.replaceAll(',', '.'));
              if (v != null) Navigator.pop(ctx, v);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        final res = await ApiService.updateWaterQuantity(quantiteEau: result);
        if (res['error'] != null) {
          _showSnack('Erreur serveur', Colors.red);
          return;
        }
        await _loadCapacity();
        _showSnack('Quantité mise à jour ✓', Colors.green);
      } catch (_) {
        _showSnack('Erreur lors de la mise à jour', Colors.red);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: color,
      duration:        const Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────────────────────
  // MAP SCREEN
  // ─────────────────────────────────────────────────────────

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
              urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.water_delivery_app',
            ),
            if (_polylines.isNotEmpty)
              PolylineLayer(polylines: _polylines),
            MarkerLayer(
              markers: [
                if (_gpsReady && _simPosition == null)
                  Marker(
                    point:  _currentPosition,
                    width:  18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color:  Colors.blue.withOpacity(0.25),
                        shape:  BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                ..._markers,
                if (_simPosition != null)
                  Marker(
                    point:  _simPosition!,
                    width:  56,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        color:  Colors.orange,
                        shape:  BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color:      Colors.black38,
                            blurRadius: 10,
                            offset:     Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_shipping,
                          color: Colors.white, size: 26),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                            color:      Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset:     const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_shipping,
                            color: Color(0xFF1E3A8A), size: 24),
                        const SizedBox(width: 8),
                        _loadingCapacity
                            ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                            : Text(
                            '${_capacityLiters.toStringAsFixed(0)} L',
                            style: const TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.bold,
                              color:      Color(0xFF1E3A8A),
                            )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showEditCapacityDialog,
                          child: const Icon(Icons.edit,
                              size: 18, color: Colors.black54),
                        ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color:      Colors.black.withOpacity(0.1),
                            blurRadius: 8)],
                      ),
                      child: _loadingRoutes
                          ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                          : Icon(Icons.gps_fixed,
                          color: _gpsReady
                              ? Colors.green
                              : Colors.grey,
                          size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // FABs
        Positioned(
          right: 16,
          top:   MediaQuery.of(context).padding.top + 100,
          child: FloatingActionButton(
            mini:            true,
            heroTag:         'locate',
            backgroundColor: Colors.white,
            onPressed: () =>
                _mapController.move(_currentPosition, 14.0),
            child: const Icon(Icons.my_location,
                color: Color(0xFF1E3A8A)),
          ),
        ),
        Positioned(
          right: 16,
          top:   MediaQuery.of(context).padding.top + 160,
          child: FloatingActionButton(
            mini:            true,
            heroTag:         'refresh_routes',
            backgroundColor: Colors.white,
            onPressed:       isOnline ? _loadOptimizedRoutes : null,
            child: Icon(Icons.refresh,
                color: isOnline
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey),
          ),
        ),

        if (isOnline && _optimizedStops.isNotEmpty)
          Positioned(
            bottom: 90,
            left:   0,
            right:  0,
            child: _buildRouteSummaryPanel(),
          )
        else
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: _buildOnlineToggle(),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Route summary panel (with simulation controls)
  // ─────────────────────────────────────────────────────────
  Widget _buildRouteSummaryPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset:     const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color:        Color(0xFF1E3A8A),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _routeIsValid
                        ? 'Itinéraire optimisé ✓'
                        : 'Itinéraire (non validé)',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize:   10,
                    ),
                  ),
                ),
                if (_totalDistanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_totalDistanceKm!.toStringAsFixed(1)} km total',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    for (final stop in _optimizedStops) {
                      await ApiService.cancelCommande(stop.mongoId);
                    }
                    setState(() {
                      _optimizedStops  = [];
                      _polylines       = [];
                      _markers         = [];
                      _totalDistanceKm = null;
                      _testOrders      = [];
                      _fullRoutePoints = [];
                    });
                    _stopSimulation();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Annuler tout',
                        style: TextStyle(
                            color:      Colors.white,
                            fontSize:   11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Simulation control bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(
                    color: Colors.orange.shade100, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Simulation de déplacement',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      Colors.orange,
                    ),
                  ),
                ),
                if (_simRunning) ...[
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      value: _fullRoutePoints.isEmpty
                          ? 0
                          : _simIndex /
                          (_fullRoutePoints.length - 1),
                      color:           Colors.orange,
                      backgroundColor: Colors.orange.shade100,
                      minHeight:       4,
                      borderRadius:    BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _SimButton(
                  icon:    Icons.play_arrow,
                  color:   Colors.green,
                  enabled: !_simRunning && _fullRoutePoints.isNotEmpty,
                  onTap:   _startSimulation,
                  tooltip: _simStarted ? 'Reprendre' : 'Démarrer',
                ),
                const SizedBox(width: 6),
                _SimButton(
                  icon:    Icons.pause,
                  color:   Colors.orange,
                  enabled: _simRunning,
                  onTap:   _pauseSimulation,
                  tooltip: 'Pause',
                ),
                const SizedBox(width: 6),
                _SimButton(
                  icon:    Icons.stop,
                  color:   Colors.red,
                  enabled: _simStarted,
                  onTap:   _stopSimulation,
                  tooltip: 'Réinitialiser',
                ),
              ],
            ),
          ),

          // Stop list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: ListView.separated(
              shrinkWrap:  true,
              padding:     const EdgeInsets.symmetric(vertical: 10),
              itemCount:   _optimizedStops.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final stop  = _optimizedStops[i];
                final color = [
                  Colors.blue, Colors.green, Colors.purple,
                  Colors.orange, Colors.teal, Colors.red,
                ][i % 6];
                return ListTile(
                  dense:   true,
                  leading: CircleAvatar(
                    backgroundColor: color,
                    radius:          16,
                    child: Text('${stop.index}',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   12,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(stop.clientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   13)),
                  subtitle: stop.address.isNotEmpty
                      ? Text(stop.address,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: stop.distanceKm != null
                      ? Column(
                    mainAxisAlignment:  MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stop.distanceKm!.toStringAsFixed(1)} km',
                        style: TextStyle(
                            color:      color,
                            fontSize:   12,
                            fontWeight: FontWeight.bold),
                      ),
                      if (stop.durationMin != null)
                        Text(
                          '${stop.durationMin!.round()} min',
                          style: const TextStyle(
                              color:    Colors.grey,
                              fontSize: 10),
                        ),
                    ],
                  )
                      : null,
                  onTap: () =>
                      _mapController.move(stop.position, 15),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color:      Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset:     const Offset(0, 4))],
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
                      fontSize:   20,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline
                        ? 'En attente de commandes.'
                        : 'Vous ne recevez pas de commandes.',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
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
                    blurRadius:   15,
                    spreadRadius: 2,
                  )],
                ),
                child: Center(
                  child: Text(
                    isOnline ? 'STOP' : 'GO',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
                      Icon(Icons.admin_panel_settings,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text('Retourner au tableau de bord Gérant',
                          style: TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.white70, size: 12),
                    ],
                  ),
                ),
              ),
            ),
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
        currentIndex:        currentIndex,
        onTap: (i) => setState(() => currentIndex = i),
        type:                BottomNavigationBarType.fixed,
        backgroundColor:     const Color(0xFF1E3A8A),
        selectedItemColor:   Colors.white,
        unselectedItemColor: Colors.white60,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.map),      label: 'Carte'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'Commandes'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history),  label: 'Historique'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person),   label: 'Profil'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Small reusable simulation button
// ─────────────────────────────────────────────────────────
class _SimButton extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final bool         enabled;
  final VoidCallback onTap;
  final String       tooltip;

  const _SimButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width:  32,
          height: 32,
          decoration: BoxDecoration(
            color:        enabled ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
            boxShadow: enabled
                ? [BoxShadow(
                color:      color.withOpacity(0.4),
                blurRadius: 6,
                offset:     const Offset(0, 2))]
                : null,
          ),
          child: Icon(icon,
              color: enabled ? Colors.white : Colors.grey.shade500,
              size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Data model for a route stop
// ─────────────────────────────────────────────────────────
class _RouteStop {
  final int     index;
  final String  mongoId;
  final String  clientName;
  final LatLng  position;
  final String  address;
  final double  quantity;
  final double? distanceKm;
  final double? durationMin;

  const _RouteStop({
    required this.index,
    required this.mongoId,
    required this.clientName,
    required this.position,
    required this.address,
    required this.quantity,
    this.distanceKm,
    this.durationMin,
  });

  _RouteStop copyWith({double? distanceKm, double? durationMin}) {
    return _RouteStop(
      index:       index,
      mongoId:     mongoId,
      clientName:  clientName,
      position:    position,
      address:     address,
      quantity:    quantity,
      distanceKm:  distanceKm  ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
    );
  }
}