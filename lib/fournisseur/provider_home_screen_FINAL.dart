import 'dart:async';
import 'dart:math' as dartMath;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'chauffeur_review_screen.dart';
import 'heatmap_painter.dart';
import 'orders_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';
import '../services/osrmservice.dart';

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
  bool _showHeatmap = false;
  bool isOnline     = false;
  int  currentIndex = 0;
  Map<String, String> _stopChauffeur = {};
  LatLng _currentPosition = const LatLng(36.76639, 3.47717);
  bool   _gpsReady        = false;
  List<_RouteStop> _allStops = [];
  double _capacityLiters  = 0;
  bool   _loadingCapacity = true;
  int _nbTestVehicles = 1;
  List<Polyline> _polylines     = [];
  List<Marker>   _markers       = [];
  bool           _loadingRoutes = false;
  List<Map<String, dynamic>> _testChauffeurs = [];
  List<_RouteStop> _optimizedStops = [];
  double?          _totalDistanceKm;
  bool             _routeIsValid   = false;

  List<Map<String, dynamic>> _testOrders = [];
  Map<String, bool> _stopAcceptance = {};
  Map<String, String> _orderStatus = {}; // 'pending' | 'accepted' | 'rejected'
  StreamSubscription<Position>? _gpsSub;
  Timer?                        _gpsUploadTimer;

  // ── Simulation state ────────────────────────────────────────────
  Map<String, List<LatLng>> _routePointsByChauffeur = {}; // chauffeur nom → points
  List<LatLng> _fullRoutePoints = [];
  int  _simIndex   = 0;
  bool _simRunning = false;
  bool _simStarted = false;
  LatLng? _simPosition;

  static const int      _simStepSize = 1;
  static const Duration _simInterval = Duration(milliseconds: 200);

  Timer? _simTimer;

  int  _currentStopTarget    = 0;
  bool _arrivalDialogShowing = false;
  int  _simUploadCounter     = 0;
  static const int _uploadEveryNTicks = 10;

  // ── NEW: tracks whether the current route is a preview (not yet accepted) ──
  bool _isPreviewRoute = false;

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

  Future<void> _startSimulationFromChauffeur(String acceptedMongoId) async {
    final chauffeurNom = _stopChauffeur[acceptedMongoId];

    LatLng startPos = _currentPosition;

    if (chauffeurNom != null) {
      final chauffeur = _testChauffeurs.firstWhere(
            (c) => c['nom'].toString() == chauffeurNom,
        orElse: () => <String, dynamic>{},
      );
      final lat = (chauffeur['lat'] as num?)?.toDouble();
      final lon = (chauffeur['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        startPos = LatLng(lat, lon);
      }
    }

    _log('_startSimulationFromChauffeur: startPos=$startPos');

    List<LatLng> correctedRoute = List.from(_fullRoutePoints);

    if (correctedRoute.isNotEmpty) {
      try {
        final result = await OsrmService.getRouteWithMetrics(
          startPos,
          correctedRoute.first,
        );
        final prependPts = result['points'] as List<LatLng>;
        correctedRoute = [...prependPts, ...correctedRoute.skip(1)];
      } catch (_) {
        correctedRoute = [startPos, ...correctedRoute];
      }
    }

    setState(() {
      _fullRoutePoints = correctedRoute;
      _simIndex          = 0;
      _simPosition       = correctedRoute.isNotEmpty ? correctedRoute.first : null;
      _currentStopTarget = 0;
      _simRunning        = true;
      _simStarted        = true;
    });

    // Now start the timer directly — skip the chauffeur lookup branch
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




  void _startSimulationForChauffeur(String chauffeurNom) {
    final route = _routePointsByChauffeur[chauffeurNom] ?? [];
    if (route.isEmpty) {
      _showSnack('Pas d\'itinéraire pour $chauffeurNom', Colors.orange);
      return;
    }

    final chauffeurStops = _allStops
        .where((s) =>
    _orderStatus[s.mongoId] == 'accepted' &&
        _stopChauffeur[s.mongoId] == chauffeurNom)
        .toList();

    _simTimer?.cancel();

    setState(() {
      _fullRoutePoints      = List<LatLng>.from(route);
      _optimizedStops       = chauffeurStops;
      _currentStopTarget    = 0;
      _simIndex             = 0;
      _simPosition          = route.first;
      _simStarted           = false;
      _simRunning           = false;
      _arrivalDialogShowing = false;
      currentIndex          = 0; // ← switch to map tab
    });

    // Move map to chauffeur starting position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(route.first, 14.0); // ← zoom to truck
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _startSimulation();
      });
    });
  }

  void _showChauffeurSummarySheet() {
    final colorOptions = [
      const Color(0xFF1565C0), Colors.green.shade700,
      Colors.orange.shade700,  Colors.purple.shade700,
      Colors.red.shade700,     Colors.teal.shade700,
    ];
    final Map<String, Color> chauffeurColors = {};
    for (int i = 0; i < _testChauffeurs.length; i++) {
      chauffeurColors[_testChauffeurs[i]['nom'].toString()] =
      colorOptions[i % colorOptions.length];
    }

    final Map<String, List<_RouteStop>> byChauffeur = {};
    for (final stop in _allStops) {
      final nom = _stopChauffeur[stop.mongoId];
      if (nom == null) continue;
      byChauffeur.putIfAbsent(nom, () => []).add(stop);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('Résumé des chauffeurs',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: byChauffeur.entries.map((entry) {
                    final nom   = entry.key;
                    final stops = entry.value;
                    final color = chauffeurColors[nom] ?? Colors.grey;
                    final totalKm  = stops.where((s) => s.distanceKm != null)
                        .fold(0.0, (sum, s) => sum + s.distanceKm!);
                    final totalMin = stops.where((s) => s.durationMin != null)
                        .fold(0.0, (sum, s) => sum + s.durationMin!);

                    return ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: Colors.white, size: 16),
                      ),
                      title: Text(nom, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${stops.length} arrêt(s) · ${totalKm.toStringAsFixed(1)} km · ${totalMin.round()} min',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      children: stops.map((stop) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: color,
                          radius: 14,
                          child: Text('${stop.index}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(stop.clientName,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: stop.address.isNotEmpty
                            ? Text(stop.address,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: stop.distanceKm != null
                            ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${stop.distanceKm!.toStringAsFixed(1)} km',
                                style: TextStyle(color: color, fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            if (stop.durationMin != null)
                              Text('${stop.durationMin!.round()} min',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 10)),
                          ],
                        )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _mapController.move(stop.position, 15);
                        },
                      )).toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showSimulationPicker() {
    // Get chauffeurs with accepted orders
    final Map<String, List<_RouteStop>> acceptedByChauffeur = {};
    for (final stop in _allStops) {
      if (_orderStatus[stop.mongoId] == 'accepted') {
        final nom = _stopChauffeur[stop.mongoId] ?? 'default';
        acceptedByChauffeur.putIfAbsent(nom, () => []).add(stop);
      }
    }

    if (acceptedByChauffeur.isEmpty) {
      _showSnack('Aucune commande acceptée', Colors.orange);
      return;
    }

    // If only one chauffeur, start directly
    if (acceptedByChauffeur.length == 1) {
      final nom = acceptedByChauffeur.keys.first;
      _startSimulationForChauffeur(nom);
      return;
    }

    // Build chauffeur colors
    final colorOptions = [
      const Color(0xFF1565C0), Colors.green.shade700,
      Colors.orange.shade700,  Colors.purple.shade700,
      Colors.red.shade700,     Colors.teal.shade700,
    ];
    final Map<String, Color> chauffeurColors = {};
    for (int i = 0; i < _testChauffeurs.length; i++) {
      chauffeurColors[_testChauffeurs[i]['nom'].toString()] =
      colorOptions[i % colorOptions.length];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Choisir un chauffeur à simuler',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...acceptedByChauffeur.entries.map((entry) {
              final nom    = entry.key;
              final stops  = entry.value;
              final color  = chauffeurColors[nom] ?? Colors.grey;
              final route  = _routePointsByChauffeur[nom] ?? [];

              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _startSimulationForChauffeur(nom);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nom,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              '${stops.length} arrêt(s) · '
                                  '${route.length > 1 ? "itinéraire prêt" : "pas de route"}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.play_circle_filled, color: color, size: 28),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }


  void _showOrderAcceptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final pending  = _allStops.where((s) => _orderStatus[s.mongoId] == 'pending').toList();
          final accepted = _allStops.where((s) => _orderStatus[s.mongoId] == 'accepted').toList();
          final rejected = _allStops.where((s) => _orderStatus[s.mongoId] == 'rejected').toList();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // handle
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.checklist_rtl,
                          color: Color(0xFF1E3A8A), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Commandes à traiter',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      if (pending.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text('${pending.length} en attente',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [

                      // ── PENDING ──────────────────────────────
                      if (pending.isNotEmpty) ...[
                        _sectionHeader('En attente', Colors.orange, pending.length),
              ...pending.map((stop) => Column(
            children: [
              // chauffeur badge
              if (_stopChauffeur[stop.mongoId] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 13, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 4),
                      Text(
                        _stopChauffeur[stop.mongoId]!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              _orderTile(
                stop: stop,
                status: 'pending',
                onAccept: () {
                  setModal(() => setState(() {        // ← setModal + setState together
                    _orderStatus[stop.mongoId] = 'accepted';
                    _isPreviewRoute = false;
                  }));
                  Navigator.pop(ctx);
                  _rebuildRouteFromAccepted();
                },
                onReject: () {
                  setModal(() => setState(() =>
                  _orderStatus[stop.mongoId] = 'rejected'));
                  _rebuildRouteFromAccepted();
                },
              ),
            ],
          )),
                      ],

                      // ── ACCEPTED ─────────────────────────────
                      // ── ACCEPTED section — show chauffeur + route info ────────
                      if (accepted.isNotEmpty) ...[
                        _sectionHeader('Acceptées', Colors.green, accepted.length),
                        ...accepted.map((stop) => Column(
                          children: [
                            if (_stopChauffeur[stop.mongoId] != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 13, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      _stopChauffeur[stop.mongoId]!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _orderTile(
                              stop: stop,
                              status: 'accepted',
                              onAccept: () {},
                              onReject: () {
                                setModal(() => setState(() =>
                                _orderStatus[stop.mongoId] = 'pending'));
                                _rebuildRouteFromAccepted();
                              },
                            ),
                          ],
                        )),
                      ],

                      // ── REJECTED ─────────────────────────────
                      if (rejected.isNotEmpty) ...[
                        _sectionHeader('Refusées', Colors.red, rejected.length),
                        ...rejected.map((stop) => _orderTile(
                          stop: stop,
                          status: 'rejected',
                          onAccept: () {
                            setModal(() => setState(() =>
                            _orderStatus[stop.mongoId] = 'pending'));
                            _rebuildRouteFromAccepted();
                          },
                          onReject: () {},
                        )),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child:ElevatedButton.icon(
                      onPressed: accepted.isNotEmpty
                          ? () {
                        Navigator.pop(ctx);
                        setState(() => currentIndex = 0); // ← switch to map tab
                      }
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(accepted.isEmpty
                          ? 'Aucune commande acceptée'
                          : 'Voir itinéraire — ${accepted.length} arrêt(s) ✓'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    OrdersScreen(
      onOrdersRegenerated: () {
        setState(() {
          _orderStatus.clear();
          _optimizedStops.clear();
          _stopChauffeur.clear();
        });
      },
    );
  }
  Widget _sectionHeader(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(width: 6),
        Text('($count)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _orderTile({
    required _RouteStop stop,
    required String status,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    final colors = [
      Colors.blue, Colors.green, Colors.purple,
      Colors.orange, Colors.teal, Colors.red,
    ];
    final color = colors[(_optimizedStops.indexOf(stop)) % 6];

    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';

    return Opacity(
      opacity: isRejected ? 0.45 : 1.0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRejected
              ? Colors.grey.shade300
              : isAccepted
              ? Colors.green.shade100
              : color.withOpacity(0.15),
          radius: 18,
          child: Text('${stop.index}',
              style: TextStyle(
                  color: isRejected
                      ? Colors.grey
                      : isAccepted
                      ? Colors.green.shade700
                      : color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(stop.clientName,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: isRejected ? TextDecoration.lineThrough : null,
                color: isRejected ? Colors.grey : Colors.black87)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stop.address.isNotEmpty)
              Text(stop.address,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            if (stop.distanceKm != null)
              Text(
                '${stop.distanceKm!.toStringAsFixed(1)} km'
                    '${stop.durationMin != null ? ' · ${stop.durationMin!.round()} min' : ''}'
                    ' · ${stop.quantity.toStringAsFixed(0)} L',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500),
              ),
          ],
        ),
        trailing: status == 'pending'
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // reject
            GestureDetector(
              onTap: onReject,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Icon(Icons.close,
                    color: Colors.red.shade400, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            // accept
            GestureDetector(
              onTap: onAccept,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Icon(Icons.check,
                    color: Colors.green.shade600, size: 18),
              ),
            ),
          ],
        )
            : status == 'accepted'
            ? GestureDetector(
          onTap: onReject, // undo → back to pending
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text('Annuler',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600)),
          ),
        )
            : GestureDetector(
          onTap: onAccept, // restore → back to pending
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text('Restaurer',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Future<void> _rebuildRouteFromAccepted() async {
    final acceptedIds = _orderStatus.entries
        .where((e) => e.value == 'accepted')
        .map((e) => e.key)
        .toSet();

    if (acceptedIds.isEmpty) {
      setState(() {
        _polylines                = [];
        _markers                  = _buildMarkers([]);
        _fullRoutePoints          = [];
        _routePointsByChauffeur   = {};
        _optimizedStops           = [];
        _totalDistanceKm          = null;
      });
      return;
    }

    final filteredStops = _allStops
        .where((s) => acceptedIds.contains(s.mongoId))
        .toList();

    if (filteredStops.isEmpty) return;

    // Group by chauffeur
    final Map<String, List<_RouteStop>> byChauffeur = {};
    for (final stop in filteredStops) {
      final nom = _stopChauffeur[stop.mongoId] ?? 'default';
      byChauffeur.putIfAbsent(nom, () => []).add(stop);

    }

    final List<Polyline>             allPolylines          = [];
    final Map<String, List<LatLng>>  routePointsByChauffeur = {};
    double                           totalDist              = 0;

    final routeColors = [
      const Color(0xFF1565C0), Colors.green.shade700,
      Colors.orange.shade700,  Colors.purple.shade700,
      Colors.red.shade700,     Colors.teal.shade700,
    ];
    int colorIdx = 0;

    for (final entry in byChauffeur.entries) {
      final nom   = entry.key;
      final stops = entry.value;

      // ── Get THIS chauffeur's real GPS position ──
      final chauffeurData = _testChauffeurs.firstWhere(
            (c) => c['nom'].toString() == nom,
        orElse: () => <String, Object>{},
      );

      final double startLat = (chauffeurData['lat'] as num?)?.toDouble()
          ?? _currentPosition.latitude;
      final double startLon = (chauffeurData['lon'] as num?)?.toDouble()
          ?? _currentPosition.longitude;
      final startPoint = LatLng(startLat, startLon);
      print('>>> rebuild: nom=$nom');
      print('>>> chauffeurData: $chauffeurData');
      print('>>> _testChauffeurs: ${_testChauffeurs.map((c) => c['nom']).toList()}');
      print('>>> startLat=$startLat startLon=$startLon');
      print('>>> _currentPosition=${_currentPosition.latitude}, ${_currentPosition.longitude}');
      _log('rebuild: chauffeur=$nom starts at ($startLat, $startLon)');

      final List<LatLng> waypoints = [
        startPoint,
        ...stops.map((s) => s.position),
      ];

      final List<LatLng> routePoints = [];
      double             routeDist   = 0;

      for (int i = 0; i < waypoints.length - 1; i++) {
        try {
          final result = await OsrmService.getRouteWithMetrics(
              waypoints[i], waypoints[i + 1]);
          final pts = result['points'] as List<LatLng>;
          final d   = result['distanceKm'] as double? ?? 0;
          if (routePoints.isNotEmpty && pts.isNotEmpty) {
            routePoints.addAll(pts.skip(1));
          } else {
            routePoints.addAll(pts);
          }
          routeDist += d;
        } catch (e) {
          _log('OSRM error: $e');
        }
      }

      if (routePoints.length > 1) {
        allPolylines.add(Polyline(
          points:            routePoints,
          color:             routeColors[colorIdx % routeColors.length],
          strokeWidth:       5,
          borderStrokeWidth: 2,
          borderColor:       Colors.white,
        ));
      }

      // Store per-chauffeur — NOT concatenated
      routePointsByChauffeur[nom] = routePoints;
      totalDist += routeDist;
      colorIdx++;
    }

    if (!mounted) return;

    // For simulation: use the first (and usually only) accepted chauffeur's route
    final firstChauffeurRoute = routePointsByChauffeur.values.isNotEmpty
        ? routePointsByChauffeur.values.first
        : <LatLng>[];

    setState(() {
      _polylines                = allPolylines;
      _markers                  = _buildMarkers(filteredStops);
      _routePointsByChauffeur   = routePointsByChauffeur;
      _fullRoutePoints          = firstChauffeurRoute; // correct start point
      _optimizedStops           = filteredStops;
      _totalDistanceKm          = totalDist;
      _isPreviewRoute           = false;
    });

    _log('rebuild done: ${filteredStops.length} stops, '
        'first route starts at ${firstChauffeurRoute.isNotEmpty ? firstChauffeurRoute.first : "empty"}');
  }
  Future<void> _applyAcceptedStops() async {
    final rejectedIds = _stopAcceptance.entries
        .where((e) => e.value == false)
        .map((e) => e.key)
        .toList();

    // Optionally cancel rejected ones via API
    for (final id in rejectedIds) {
      try {
        await ApiService.cancelCommande(id);
      } catch (_) {}
    }

    setState(() {
      _optimizedStops = _optimizedStops
          .where((s) => _stopAcceptance[s.mongoId] == true)
          .toList();
    });

    // Rebuild the polyline with only accepted stops
    await _loadOptimizedRoutes();
    _showSnack(
      '${_optimizedStops.length} arrêt(s) confirmés ✓',
      Colors.green,
    );
  }
  // ─────────────────────────────────────────────────────────
  // PUBLIC — NEW: preview optimized route for pending orders
  // Called by OrdersScreen right after orders are generated/loaded,
  // BEFORE the chauffeur accepts anything.
  // ─────────────────────────────────────────────────────────
  void previewRouteForOrders(List<Map<String, dynamic>> pendingOrders, {int nbVehicules = 1}) {
    final fakeOrders = pendingOrders
        .where((o) => o['id'].toString().startsWith('gen_'))
        .toList();

    _log('previewRouteForOrders: ${fakeOrders.length} fake');

    // ← Only generate new chauffeurs if we don't have any yet
    if (_testChauffeurs.isEmpty) {
      _generateRandomChauffeurs();
    }

    setState(() {
      _testOrders     = fakeOrders;
      _isPreviewRoute = true;
      _nbTestVehicles = nbVehicules;
      _stopChauffeur.clear();
      _orderStatus.clear();
    });

    _loadOptimizedRoutes();
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC — NEW: just switch to the map tab (route already computed)
  // ─────────────────────────────────────────────────────────
  void switchToMapTab() {
    setState(() {
      currentIndex    = 0;
      _isPreviewRoute = false; // orders were accepted — route is now active
    });
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC — called by OrdersScreen after accepting a commande
  // (kept for backward compatibility — now just a thin wrapper)
  // ─────────────────────────────────────────────────────────
  void goToMapWithRoute({
    required String  commandeId,
    required double? destLat,
    required double? destLon,
    List<Map<String, dynamic>>? testOrders,
  }) {
    _log('goToMapWithRoute: commandeId=$commandeId');
    setState(() {
      currentIndex    = 0;
      _isPreviewRoute = false;
      _testOrders     = []; // ✅ always clear
    });
    if (!isOnline) {
      setState(() => isOnline = true);
      ApiService.updatePosition(
        lat: _currentPosition.latitude,
        lon: _currentPosition.longitude,
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // GPS
  // ─────────────────────────────────────────────────────────
  void _generateRandomChauffeurs() {
    final rng        = Random();
    final firstNames = ['Karim', 'Yacine', 'Mourad', 'Bilal', 'Amine'];
    final lastNames  = ['Benali', 'Meziane', 'Cherif', 'Mansouri', 'Ferhat'];

    // Spread across different Alger communes — far apart but same wilaya
    final algerPositions = [
      {'lat': 36.7372, 'lon': 3.0865},  // Hussein Dey
      {'lat': 36.7762, 'lon': 3.0589},  // El Biar
      {'lat': 36.6923, 'lon': 3.1481},  // Birtouta
      {'lat': 36.8031, 'lon': 3.0412},  // Bab Ezzouar
      {'lat': 36.7206, 'lon': 2.9871},  // Bir Mourad Raïs
      {'lat': 36.7539, 'lon': 2.8936},  // Chéraga
      {'lat': 36.8245, 'lon': 3.1023},  // Rouïba
      {'lat': 36.6711, 'lon': 3.0134},  // Eucalyptus
    ];

    final chauffeurs = List.generate(5 + rng.nextInt(3), (i) {
      final base = algerPositions[i % algerPositions.length];
      return {
        'id'        : 'chauffeur_${DateTime.now().millisecondsSinceEpoch}_$i',
        'nom'       : '${firstNames[rng.nextInt(firstNames.length)]} '
            '${lastNames[rng.nextInt(lastNames.length)]}',
        'disponible': true,
        'lat'       : (base['lat'] as double) + (rng.nextDouble() - 0.5) * 0.01,
        'lon'       : (base['lon'] as double) + (rng.nextDouble() - 0.5) * 0.01,
      };
    });

    setState(() => _testChauffeurs = chauffeurs);
  }

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
        _isPreviewRoute   = false;
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

    // ← add this guard
    if (_simRunning) return;

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
        if (_currentStopTarget < _optimizedStops.length && !_arrivalDialogShowing) {
          _arrivalDialogShowing = true;
          await _showDeliveryCompletionDialog(
              _optimizedStops[_currentStopTarget]);
        } else {
          _showSnack('Simulation terminée ✓', Colors.green);
        }
        return;
      }


      // ← move first, THEN check arrival
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

      // ← only check arrival after moving, and only if index > 10 to avoid
      //   triggering immediately at start
      if (!_arrivalDialogShowing &&
          _simIndex > 10 &&
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
            onPressed: () async {
              Navigator.pop(ctx, true); // ← close dialog with true FIRST
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChauffeurReviewScreen(
                    commandeId:  stop.mongoId,
                    clientNom:   stop.clientName,
                    volumeLivre: stop.quantity,
                    adresse:     stop.address,
                  ),
                ));
              }
            },
            icon:  const Icon(Icons.check_circle_outline),
            label: const Text('Confirmer la livraison'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    if (_loadingRoutes) return;

    _stopSimulation();

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('_loadOptimizedRoutes called');
    _log('  testOrders count : ${_testOrders.length}');
    _log('  isPreviewRoute   : $_isPreviewRoute');
    _log('  currentPosition  : ${_currentPosition.latitude.toStringAsFixed(5)}, '
        '${_currentPosition.longitude.toStringAsFixed(5)}');


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

  Future<void> _buildRouteFromTestOrders() async {
    await _loadOptimizedRoutesFromApi();
  }
  List<HeatmapData> get _heatmapPoints => _optimizedStops
      .map((s) => HeatmapData(
    s.position,
    weight: (s.quantity / 500).clamp(0.5, 5.0),
  ))
      .toList();
  // ─────────────────────────────────────────────────────────
  // REAL MODE: VRP solution from API, NN fallback
  // ─────────────────────────────────────────────────────────
  Future<void> _loadOptimizedRoutesFromApi() async {
    setState(() => _loadingRoutes = true);
    _stopChauffeur.clear();
    _log('  testOrders ids: ${_testOrders.map((o) => o['id']).toList()}');
    try {
      List<Map<String, dynamic>> commandes;
      Map<String, dynamic>       vrpResult;

      if (_testOrders.isNotEmpty) {
        _log('UNIFIED MODE: sending ${_testOrders.length} test orders → lancer-direct');

        vrpResult = await ApiService.getVrpSolutionWithOrders(
          commandes:        _testOrders,
          depotLat:         _currentPosition.latitude,
          depotLon:         _currentPosition.longitude,
          capaciteVehicule: _capacityLiters > 0 ? _capacityLiters : 5000,
          nbVehicules:      _nbTestVehicles,
          chauffeurs:       _testChauffeurs,
        );

        commandes = _testOrders.map((o) => {
          '_id':      o['id'],
          'position': {'lat': o['lat'], 'lon': o['lon']},
          'adresse':  o['address']  ?? '',
          'capacite': o['quantity'] ?? 0,
          'client':   {'prenom': o['clientName'] ?? '', 'nom': ''},
        }).toList();
      } else {
        _log('UNIFIED MODE: fetching commandes from real API...');
        commandes = (await ApiService.getCommandes(status: 'en livraison'))
            .cast<Map<String, dynamic>>();
        _log('UNIFIED MODE: ${commandes.length} commandes returned');

        if (commandes.isEmpty) {
          _log('UNIFIED MODE: no commandes → clearing map');
          setState(() {
            _polylines       = [];
            _markers         = [];
            _optimizedStops  = [];
            _totalDistanceKm = null;
            _fullRoutePoints = [];
            _loadingRoutes   = false;
          });
          _mapController.move(_currentPosition, 13);
          return;
        }

        _log('UNIFIED MODE: fetching VRP solution...');
        vrpResult = await ApiService.getVrpSolutionWithRealOrders(
          commandes:        commandes,
          depotLat:         _currentPosition.latitude,
          depotLon:         _currentPosition.longitude,
          capaciteVehicule: _capacityLiters > 0 ? _capacityLiters : 5000,
        );
      }

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

      _log('UNIFIED MODE: VRP keys = ${vrpResult.keys.toList()}');

      List<String> orderedMongoIds = [];
      bool         usedVrp         = false;

      // ── 1. Parse VRP result ──────────────────────────────────────
      if (vrpResult['error'] == null && vrpResult['routes'] != null) {
        final routes = vrpResult['routes'] as List;
        _totalDistanceKm = (vrpResult['distance_totale_km'] as num?)?.toDouble();
        _routeIsValid    = vrpResult['valide'] as bool? ?? false;

        for (final routeObj in routes) {
          final vrpIds = (routeObj['route'] as List?) ?? [];
          _log('  route ids: $vrpIds');
          for (final vid in vrpIds) {
            final key = vid.toString();
            if (commandeById.containsKey(key)) {
              orderedMongoIds.add(key);
            } else {
              _log('  WARNING: id $key not found — skipped');
            }
          }
        }

        // Debug diff
        final allVrpIds   = <String>{};
        for (final routeObj in routes) {
          for (final vid in (routeObj['route'] as List?) ?? []) {
            allVrpIds.add(vid.toString());
          }
        }
        final commandeKeys = commandeById.keys.toSet();
        _log('🔍 VRP↔commandeById diff:');
        _log('  VRP returned ids    : $allVrpIds');
        _log('  commandeById keys   : $commandeKeys');
        _log('  ✅ matched          : ${allVrpIds.intersection(commandeKeys)}');
        _log('  ❌ VRP ids not found: ${allVrpIds.difference(commandeKeys)}');
        _log('  ⚠️ commandes unused : ${commandeKeys.difference(allVrpIds)}');

        if (orderedMongoIds.isNotEmpty) {
          usedVrp = true;
          _log('UNIFIED MODE: ✅ VRP order used — ${orderedMongoIds.length} stops');
          _log('  Order: $orderedMongoIds');
        } else {
          _log('UNIFIED MODE: ⚠️ VRP produced 0 valid mongoIds → NN fallback');
        }
      } else {
        _log('UNIFIED MODE: ⚠️ VRP error or null routes → NN fallback');
        if (vrpResult['error'] != null) _log('  VRP error: ${vrpResult['error']}');
      }

      // ── 2. Populate _stopChauffeur ───────────────────────────────
      if (vrpResult['error'] == null && vrpResult['routes'] != null) {
        final routes = vrpResult['routes'] as List;
        for (int r = 0; r < routes.length; r++) {
          final routeObj     = routes[r];
          final vrpIds       = (routeObj['route'] as List?) ?? [];
          final nomChauffeur = _testChauffeurs.length > r
              ? _testChauffeurs[r]['nom'].toString()
              : (routeObj['conducteur_nom'] ?? 'Conducteur ${r + 1}').toString();
          for (final vid in vrpIds) {
            _stopChauffeur[vid.toString()] = nomChauffeur;
          }
        }
        _log('>>> _stopChauffeur populated: $_stopChauffeur');
      }

      // ── 3. NN fallback if VRP failed ─────────────────────────────
      if (!usedVrp) {
        _totalDistanceKm = null;
        _routeIsValid    = false;

        final flatList = commandeById.entries.map((e) {
          final lat = (e.value['position']?['lat'] as num?)?.toDouble();
          final lon = (e.value['position']?['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) {
            _log('  WARNING: commande ${e.key} has null position — excluded');
            return null;
          }
          final raw        = e.value['client'];
          final clientName = (raw is Map)
              ? '${raw['prenom'] ?? ''} ${raw['nom'] ?? ''}'.trim()
              : e.key;
          return <String, dynamic>{
            '_mongoId': e.key, 'lat': lat, 'lon': lon, 'clientName': clientName,
          };
        }).whereType<Map<String, dynamic>>().toList();

        _log('UNIFIED MODE: NN input: ${flatList.length} valid positions');
        final sorted    = _nearestNeighbourSort(_currentPosition, flatList);
        orderedMongoIds = sorted.map((o) => o['_mongoId'].toString()).toList();
        _log('UNIFIED MODE: NN order: $orderedMongoIds');
      }

      // ── 4. Build stops list ──────────────────────────────────────
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
        final raw        = cmd['client'];
        final clientName = (raw is Map)
            ? '${raw['prenom'] ?? ''} ${raw['nom'] ?? ''}'.trim()
            : 'Client ${i + 1}';

        _log('  stop ${i + 1}: ${clientName.isEmpty ? id : clientName}  ($lat, $lon)');
        waypoints.add(LatLng(lat, lon));
        stops.add(_RouteStop(
          index:      i + 1,
          mongoId:    id,
          clientName: clientName.isEmpty ? 'Client ${i + 1}' : clientName,
          position:   LatLng(lat, lon),
          address:    cmd['adresse'] ?? cmd['address'] ?? '',
          quantity:   (cmd['capacite'] as num?)?.toDouble() ?? 0,
        ));
      }

      if (stops.isEmpty) {
        _log('UNIFIED MODE: no valid stops after filtering — clearing map');
        setState(() {
          _polylines       = [];
          _markers         = [];
          _optimizedStops  = [];
          _totalDistanceKm = null;
          _fullRoutePoints = [];
          _loadingRoutes   = false;
        });
        return;
      }

      // ── 5. OSRM legs — per chauffeur ─────────────────────────────
      _log('UNIFIED MODE: OSRM per chauffeur...');

      final colorOptions = [
        const Color(0xFF1565C0), Colors.green.shade700,
        Colors.orange.shade700,  Colors.purple.shade700,
        Colors.red.shade700,     Colors.teal.shade700,
      ];

// Build chauffeur → stops mapping
      final Map<String, List<_RouteStop>> stopsByChauffeur = {};
      for (final stop in stops) {
        final nom = _stopChauffeur[stop.mongoId] ?? 'default';
        stopsByChauffeur.putIfAbsent(nom, () => []).add(stop);
      }

      final List<Polyline>   newPolylines    = [];
      final List<LatLng>     fullRoutePoints = [];
      double                 segmentDistKm  = 0;
      final List<double>     legDistances   = [];
      final List<double>     legDurations   = [];
      int                    colorIdx       = 0;

      for (final entry in stopsByChauffeur.entries) {
        final nom         = entry.key;
        final chauffStops = entry.value;

        // Get chauffeur start position
        final chauffeurData = _testChauffeurs.firstWhere(
              (c) => c['nom'].toString() == nom,
          orElse: () => <String, Object>{},
        );
        final double startLat = (chauffeurData['lat'] as num?)?.toDouble()
            ?? _currentPosition.latitude;
        final double startLon = (chauffeurData['lon'] as num?)?.toDouble()
            ?? _currentPosition.longitude;

        final List<LatLng> waypoints = [
          LatLng(startLat, startLon),
          ...chauffStops.map((s) => s.position),
        ];

        final List<LatLng> routePoints = [];
        double routeDist = 0;

        for (int i = 0; i < waypoints.length - 1; i++) {
          try {
            final result = await OsrmService.getRouteWithMetrics(
                waypoints[i], waypoints[i + 1]);
            final pts = result['points'] as List<LatLng>;
            final d   = result['distanceKm']  as double? ?? 0;
            final dur = result['durationMin'] as double? ?? 0;

            _log('  leg $i→${i+1} ($nom): ${d.toStringAsFixed(2)} km');

            if (routePoints.isNotEmpty && pts.isNotEmpty) {
              routePoints.addAll(pts.skip(1));
            } else {
              routePoints.addAll(pts);
            }
            routeDist    += d;
            legDistances.add(d);
            legDurations.add(dur);
          } catch (e) {
            _log('  OSRM leg error: $e');
            legDistances.add(0);
            legDurations.add(0);
          }
        }

        if (routePoints.length > 1) {
          newPolylines.add(Polyline(
            points:            routePoints,
            color:             _isPreviewRoute
                ? colorOptions[colorIdx % colorOptions.length].withOpacity(0.55)
                : colorOptions[colorIdx % colorOptions.length],
            strokeWidth:       _isPreviewRoute ? 4 : 5,
            borderStrokeWidth: 2,
            borderColor:       _isPreviewRoute
                ? Colors.white.withOpacity(0.6)
                : Colors.white,
            isDotted:          _isPreviewRoute,
          ));
        }

        fullRoutePoints.addAll(routePoints);
        segmentDistKm += routeDist;
        colorIdx++;
      }

      // ── 6. Enrich stops with distances ───────────────────────────
// ── 6. Enrich stops with distances ───────────────────────────
// Build a map of mongoId → (distance, duration) from per-chauffeur legs
      final Map<String, double> stopDistanceMap = {};
      final Map<String, double> stopDurationMap = {};

      int legIdx = 0;
      for (final entry in stopsByChauffeur.entries) {
        final chauffStops = entry.value;
        // skip first leg (chauffeur → first stop) — that's leg 0 for this chauffeur
        // legs are: [chauffeur→stop0, stop0→stop1, stop1→stop2, ...]
        for (int s = 0; s < chauffStops.length; s++) {
          if (legIdx < legDistances.length) {
            stopDistanceMap[chauffStops[s].mongoId] = legDistances[legIdx];
            stopDurationMap[chauffStops[s].mongoId] = legDurations[legIdx];
          }
          legIdx++;
        }
      }

      final List<_RouteStop> enrichedStops = stops.map((stop) {
        return stop.copyWith(
          distanceKm:  stopDistanceMap[stop.mongoId],
          durationMin: stopDurationMap[stop.mongoId],
        );
      }).toList();


      // ── 7. Init orderStatus for new stops ────────────────────────
      final enrichedIds = enrichedStops.map((s) => s.mongoId).toSet();
      _orderStatus.removeWhere((id, _) => !enrichedIds.contains(id));
      for (final s in enrichedStops) {
        _orderStatus.putIfAbsent(s.mongoId, () => 'pending');
      }

      // ── 9. setState ───────────────────────────────────────────────
      setState(() {
        _polylines       = newPolylines;
        _markers         = _buildMarkers(enrichedStops);
        _optimizedStops  = enrichedStops;
        _allStops        = enrichedStops;
        _totalDistanceKm = _totalDistanceKm ?? segmentDistKm;
        _fullRoutePoints = List<LatLng>.from(fullRoutePoints);
        _loadingRoutes   = false;
      });

      // ── 10. Fit map bounds ────────────────────────────────────────
      if (waypoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(waypoints);
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(
              padding: EdgeInsets.fromLTRB(40, 120, 40, 300)),
        );
      }

    } catch (e, st) {
      _log('UNIFIED MODE ERROR: $e');
      _log('  $st');
      if (!mounted) return;
      setState(() => _loadingRoutes = false);
      _showSnack('Erreur lors du chargement des itinéraires', Colors.red);
    }
  }

  // ─────────────────────────────────────────────────────────
  // SHARED MARKER BUILDER
  // ─────────────────────────────────────────────────────────
  List<Marker> _buildMarkers(List<_RouteStop> stops) {
    // ── Build chauffeur → color mapping ──────────────────────
    final colorOptions = [
      Colors.blue, Colors.green, Colors.purple,
      Colors.orange, Colors.teal, Colors.red,
    ];
    final Map<String, Color> chauffeurColors = {};
    for (int i = 0; i < _testChauffeurs.length; i++) {
      chauffeurColors[_testChauffeurs[i]['nom'].toString()] =
      colorOptions[i % colorOptions.length];
    }

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
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 28),
          ),
        ),
      ),
    ];

    // ── Stop markers (colored by assigned chauffeur) ──────────
    for (int i = 0; i < stops.length; i++) {
      final stop             = stops[i];
      final assignedChauffeur = _stopChauffeur[stop.mongoId];
      final color = assignedChauffeur != null && chauffeurColors.containsKey(assignedChauffeur)
          ? chauffeurColors[assignedChauffeur]!
          : colorOptions[i % colorOptions.length];
      final markerColor = _isPreviewRoute ? color.withOpacity(0.65) : color;

      markers.add(Marker(
        point:  stop.position,
        width:  72,
        height: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        markerColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Text(
                stop.distanceKm != null
                    ? '${stop.index}. ${stop.distanceKm!.toStringAsFixed(1)} km\n'
                    '${stop.durationMin?.round()} min'
                    : '${stop.index}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontSize: 9,
                  fontWeight: FontWeight.bold, height: 1.3,
                ),
              ),
            ),
            Icon(Icons.location_on, color: markerColor, size: 32),
          ],
        ),
      ));
    }

    // ── Chauffeur markers (same color as their stops) ─────────
    for (final c in _testChauffeurs) {
      final nom = c['nom'].toString();
      final lat = (c['lat'] as num?)?.toDouble();
      final lon = (c['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final hasAccepted = _stopChauffeur.entries
          .any((e) => e.value == nom && _orderStatus[e.key] == 'accepted');

      if (!_isPreviewRoute && !hasAccepted) continue;

      final chauffeurColor = chauffeurColors[nom] ?? Colors.grey.shade600;
      final displayColor   = _isPreviewRoute && !hasAccepted
          ? chauffeurColor.withOpacity(0.5)
          : chauffeurColor;

      markers.add(Marker(
        point:  LatLng(lat, lon),
        width:  64,
        height: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color:  displayColor,
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            Text(
              nom.split(' ').first,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: displayColor,
              ),
            ),
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
            if (_showHeatmap && _optimizedStops.isNotEmpty)
              MarkerLayer(
                markers: _optimizedStops.map((stop) => Marker(
                  point: stop.position,
                  width: 80,
                  height: 80,
                  child: _HeatmapDot(
                    intensity: stop.quantity > 0
                        ? (stop.quantity / 2000).clamp(0.0, 1.0)
                        : 0.5,
                  ),
                )).toList(),
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showHeatmap = !_showHeatmap),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _showHeatmap
                              ? const Color(0xFF1E3A8A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:      Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_fire_department,
                          color: _showHeatmap
                              ? Colors.white
                              : const Color(0xFF1E3A8A),
                          size: 20,
                        ),
                      ),
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
            bottom: 20,
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
    // ✅ CHANGED: show different header when route is a preview
    final headerTitle = _isPreviewRoute
        ? '📍 Aperçu — acceptez les commandes pour démarrer'
        : (_routeIsValid ? 'Itinéraire optimisé ✓' : 'Itinéraire (non validé)');
    final headerColor = _isPreviewRoute
        ? const Color(0xFF455A64)   // grey-blue for preview
        : const Color(0xFF1E3A8A);  // dark blue for active
    return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 1, // ← max 45% of screen
        ),
   child:  Container(
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
                horizontal: 1, vertical: 8),
            decoration: BoxDecoration(
              color:        headerColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                if (_optimizedStops.isNotEmpty)
                  GestureDetector(
                    onTap: _showOrderAcceptSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(left: 40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.checklist_rtl, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _orderStatus.values.where((v) => v == 'count').isNotEmpty
                                ? '${_orderStatus.values.where((v) => v == "count").length} en attente'
                                : 'Commandes',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      _isPreviewRoute ? Icons.preview : Icons.route,
                      color: Colors.white, size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headerTitle,
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
                        if (!_isPreviewRoute) {
                          for (final stop in _optimizedStops) {
                            await ApiService.cancelCommande(stop.mongoId);
                          }
                        }
                        setState(() {
                          _optimizedStops  = [];
                          _polylines       = [];
                          _markers         = [];
                          _totalDistanceKm = null;
                          _testOrders      = [];
                          _fullRoutePoints = [];
                          _isPreviewRoute  = false;
                        });
                        _stopSimulation();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPreviewRoute ? Colors.blueGrey : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isPreviewRoute ? 'Effacer' : 'Annuler tout',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          ),


          if (!_isPreviewRoute)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
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
                    onTap:   _showSimulationPicker,
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

          // ✅ CHANGED: in preview mode show a "go accept orders" CTA
          if (_isPreviewRoute)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade100, width: 1),
                ),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: Colors.blue.shade400, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rendez-vous sur "Commandes" pour accepter ou refuser chaque livraison',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700),
                  ),
                ),

              ]),
            ),


          // ── Chauffeur summary button ──────────────────────────────
          if (_testChauffeurs.isNotEmpty && _stopChauffeur.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: GestureDetector(
                onTap: _showChauffeurSummarySheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.people, color: Color(0xFF1E3A8A), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_testChauffeurs.length} chauffeurs — voir détails',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Color(0xFF1E3A8A), size: 16),
                  ]),
                ),
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
                final displayColor =
                _isPreviewRoute ? color.withOpacity(0.6) : color;
                return ListTile(
                  dense:   true,
                  leading: CircleAvatar(
                    backgroundColor: displayColor,
                    radius:          16,
                    child: Text('${stop.index}',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   12,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(stop.clientName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   13,
                          color: _isPreviewRoute
                              ? Colors.black54
                              : Colors.black87)),
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
                            color:      displayColor,
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
class _HeatmapDot extends StatelessWidget {
  final double intensity; // 0.0 → 1.0

  const _HeatmapDot({required this.intensity});

  @override
  Widget build(BuildContext context) {
    // Interpolate colour: blue → green → yellow → red
    final Color color;
    if (intensity < 0.33) {
      color = Color.lerp(Colors.blue, Colors.green, intensity / 0.33)!;
    } else if (intensity < 0.66) {
      color = Color.lerp(Colors.green, Colors.yellow, (intensity - 0.33) / 0.33)!;
    } else {
      color = Color.lerp(Colors.yellow, Colors.red, (intensity - 0.66) / 0.34)!;
    }

    return CustomPaint(
      painter: _HeatmapPainter(color: color),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Color color;
  const _HeatmapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer glow (low opacity)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Mid ring
    canvas.drawCircle(
      center,
      radius * 0.65,
      Paint()
        ..color = color.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Core dot
    canvas.drawCircle(
      center,
      radius * 0.28,
      Paint()..color = color.withOpacity(0.6),
    );
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.color != color;
}