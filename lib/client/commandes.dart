import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:test2/client/suivi.dart';

const String _baseUrl = 'http://10.0.2.2:8000';

// Model for a conducteur fetched from the API
class _Conducteur {
  final int    id;
  final String nom;
  final double lat;
  final double lon;
  final int    capacity;
  final int    load;
  final int    available;

  _Conducteur({
    required this.id,
    required this.nom,
    required this.lat,
    required this.lon,
    required this.capacity,
    required this.load,
  }) : available = capacity - load;

  factory _Conducteur.fromSolution(Map<String, dynamic> j) => _Conducteur(
    id:       j['id'],
    nom:      j['nom'],
    lat:      (j['lat'] as num).toDouble(),
    lon:      (j['lon'] as num).toDouble(),
    capacity: j['capacity'],
    load:     j['load'] ?? 0,
  );

  factory _Conducteur.fromGps(Map<String, dynamic> j) => _Conducteur(
    id:       j['id'],
    nom:      j['nom'],
    lat:      (j['lat'] as num).toDouble(),
    lon:      (j['lon'] as num).toDouble(),
    capacity: 400,
    load:     0,
  );
}

class commandes extends StatefulWidget {
  const commandes({super.key});

  @override
  State<commandes> createState() => _CommandesState();
}

class _CommandesState extends State<commandes> {
  String?      selectedPosition;
  String?      selectedVolume;
  _Conducteur? selectedFournisseur;
  bool         _submitting = false;
  bool         _gettingLocation = false;

  double? _selectedLat;
  double? _selectedLon;
  int     _nextOrderId = 20;

  List<_Conducteur> _conducteurs    = [];
  bool              _loadingDrivers = false;
  String?           _driversError;

  final List<String> volumes = [
    '100 L', '500 L', '1000 L', '2 000 L', '3 000 L', '5 000 L',
  ];

  @override
  void initState() {
    super.initState();
    _setupAndLoad();
  }

  // ── Register conducteurs first, then load them ────────────
  Future<void> _setupAndLoad() async {
    // Always register conducteurs on app start so they exist in backend
    // TODO: replace with real driver data from your database
    try {
      await http.post(
        Uri.parse('$_baseUrl/setup/conducteurs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([
          {'id': 1, 'capacity': 500, 'lat': 36.7600, 'lon': 3.0500, 'nom': 'Conducteur A'},
          {'id': 2, 'capacity': 2000, 'lat': 36.7450, 'lon': 3.0700, 'nom': 'Conducteur B'},
          {'id': 3, 'capacity': 1000, 'lat': 36.7580, 'lon': 3.0800, 'nom': 'Conducteur C'},
        ]),
      );
    } catch (_) {
      // Backend not reachable yet — _loadConducteurs will show the error
    }
    _loadConducteurs();
  }

  // ── Get real GPS position ─────────────────────────────────
  Future<void> _useMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      // Check & request permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showError('Permission de localisation refusée.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLat     = pos.latitude;
        _selectedLon     = pos.longitude;
        selectedPosition =
        '📍 ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position obtenue ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      _showError('Impossible d\'obtenir la position GPS.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // ── Fetch available conducteurs from API ──────────────────
  Future<void> _loadConducteurs() async {
    setState(() { _loadingDrivers = true; _driversError = null; });
    try {
      // Try solution first (has real load info from NSGA-II)
      final solRes = await http.get(Uri.parse('$_baseUrl/solution'));
      if (solRes.statusCode == 200) {
        final data = jsonDecode(solRes.body);
        final list = (data['conducteurs'] as List)
            .map((e) => _Conducteur.fromSolution(e))
            .where((c) => c.available > 0)
            .toList();
        setState(() => _conducteurs = list);
      } else {
        // No solution yet — show all registered conducteurs from GPS endpoint
        final posRes = await http.get(Uri.parse('$_baseUrl/gps/positions'));
        if (posRes.statusCode == 200) {
          final list = jsonDecode(posRes.body) as List;
          if (list.isNotEmpty) {
            setState(() {
              _conducteurs = list.map((e) => _Conducteur.fromGps(e)).toList();
            });
          } else {
            // GPS endpoint also empty — conducteurs not registered yet, retry setup
            await _setupAndLoad();
          }
        } else {
          setState(() => _driversError = 'Impossible de charger les fournisseurs.');
        }
      }
    } catch (_) {
      setState(() => _driversError = 'Vérifiez que le serveur backend tourne.');
    } finally {
      setState(() => _loadingDrivers = false);
    }
  }

  int _parseVolume(String vol) =>
      int.tryParse(vol.replaceAll(' ', '').replaceAll('L', '')) ?? 0;

  // ── Confirm order ─────────────────────────────────────────
  Future<void> _confirmOrder() async {
    if (!_canConfirm) return;
    setState(() => _submitting = true);
    try {
      final lat    = _selectedLat ?? 36.7538;
      final lon    = _selectedLon ?? 3.0588;
      final demand = _parseVolume(selectedVolume!);

      final addRes = await http.post(
        Uri.parse('$_baseUrl/commandes/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': _nextOrderId, 'lat': lat, 'lon': lon,
          'demand': demand, 'description': selectedFournisseur!.nom,
        }),
      );
      if (addRes.statusCode != 200) { _showError('Erreur envoi commande'); return; }

      // Dynamic insertion if solution exists
      final solCheck = await http.get(Uri.parse('$_baseUrl/solution'));
      if (solCheck.statusCode == 200) {
        await http.post(
          Uri.parse('$_baseUrl/commandes/insert-dynamic'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': _nextOrderId, 'lat': lat, 'lon': lon,
            'demand': demand, 'description': selectedFournisseur!.nom,
          }),
        );
      }
      _nextOrderId++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Commande envoyée ✓  —  ${selectedFournisseur!.nom}'),
          backgroundColor: const Color(0xFF2979FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.push(context, MaterialPageRoute(builder: (_) => const suivi()));
      }
    } catch (_) {
      _showError('Erreur réseau.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── PICKERS ───────────────────────────────────────────────

  void _showPositionPicker() {
    final ctrl = TextEditingController(text: selectedPosition ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _handle(), const SizedBox(height: 12),
            const Text('Indiquez votre position',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0C2A34))),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl, autofocus: true,
              style: const TextStyle(color: Color(0xFF1A237E)),
              decoration: InputDecoration(
                hintText: 'Ex: EL HARRACH, ALGER',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF2979FF)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _quickChip('📍 Ma position actuelle', () {
                Navigator.pop(context);
                _useMyLocation();
              }),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) setState(() => selectedPosition = ctrl.text.trim());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirmer', style: TextStyle(color: Colors.white, fontSize: 16)),
            )),
          ]),
        ),
      ),
    );
  }

  void _showVolumePicker() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12), _handle(), const SizedBox(height: 12),
          const Text("Volume d'eau",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(
            itemCount: volumes.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) {
              final vol = volumes[i];
              final isSel = vol == selectedVolume;
              return GestureDetector(
                onTap: () { setState(() => selectedVolume = vol); Navigator.pop(context); },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF2979FF) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSel ? const Color(0xFF2979FF) : Colors.black12),
                  ),
                  child: Row(children: [
                    Icon(Icons.water_drop, color: isSel ? Colors.white : const Color(0xFF2979FF)),
                    const SizedBox(width: 14),
                    Text(vol, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF1A237E))),
                    const Spacer(),
                    if (isSel) const Icon(Icons.check_circle, color: Colors.white),
                  ]),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }

  // ── Fournisseur picker — REAL DATA from VRP API ───────────
  void _showFournisseurPicker() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            _handle(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Choisir un fournisseur',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF2979FF)),
                    onPressed: () {
                      Navigator.pop(context);
                      _loadConducteurs().then((_) => _showFournisseurPicker());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loadingDrivers
                  ? const Center(child: CircularProgressIndicator())
                  : _driversError != null
                  ? _buildDriversError()
                  : _conducteurs.isEmpty
                  ? _buildNoDrivers()
                  : ListView.builder(
                itemCount: _conducteurs.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (_, i) {
                  final c = _conducteurs[i];
                  final isSel = selectedFournisseur?.id == c.id;
                  return _buildDriverTile(c, isSel);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDriverTile(_Conducteur c, bool isSel) {
    final usedPct = c.capacity > 0 ? c.load / c.capacity : 0.0;

    return GestureDetector(
      onTap: () { setState(() => selectedFournisseur = c); Navigator.pop(context); },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2979FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSel ? const Color(0xFF2979FF) : Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: isSel ? Colors.white24 : const Color(0xFF0C2A34),
              child: Icon(Icons.local_shipping,
                  color: isSel ? Colors.white : const Color(0xFF2979FF)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.nom, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                  color: isSel ? Colors.white : const Color(0xFF1A237E))),
              const SizedBox(height: 2),
              Text('GPS: ${c.lat.toStringAsFixed(4)}, ${c.lon.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: isSel ? Colors.white70 : Colors.black45)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${c.available}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,
                  color: isSel ? Colors.white : const Color(0xFF2979FF))),
              Text('L dispo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white70 : Colors.blueAccent)),
            ]),
            if (isSel) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, color: Colors.white)],
          ]),
          const SizedBox(height: 10),
          // Capacity bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isSel ? Colors.white24 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSel ? Colors.white : (usedPct > 0.8 ? Colors.red : Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Charge: ${c.load}/${c.capacity} L  •  ${((1 - usedPct) * 100).toStringAsFixed(0)}% disponible',
            style: TextStyle(fontSize: 11, color: isSel ? Colors.white70 : Colors.black45),
          ),
        ]),
      ),
    );
  }

  Widget _buildDriversError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(_driversError!, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _loadConducteurs().then((_) => _showFournisseurPicker());
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildNoDrivers() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text('Aucun fournisseur disponible',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Tous les fournisseurs sont à pleine capacité.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500])),
      ]),
    ),
  );

  Widget _handle() => Center(
    child: Container(width: 40, height: 4,
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
  );

  Widget _quickChip(String label, VoidCallback onTap) => ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E))),
    backgroundColor: Colors.white, side: const BorderSide(color: Colors.black12), onPressed: onTap,
  );

  Widget _fieldTile({required IconData icon, required String hint, required String? value,
    required Widget trailing, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12)),
        child: Row(children: [
          Icon(icon, color: value != null ? const Color(0xFF2979FF) : Colors.black38, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(value ?? hint, style: TextStyle(
            color: value != null ? const Color(0xFF1A237E) : Colors.black38, fontSize: 15,
            fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
          ))),
          trailing,
        ]),
      ),
    );
  }

  bool get _canConfirm =>
      selectedPosition != null && selectedVolume != null && selectedFournisseur != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF), elevation: 0,
        leading: const BackButton(color: Color(0xFF1A237E)),
        title: const Text('commandes',
            style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.water_drop, color: Colors.blue.shade400))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12)),
            child: Column(children: [
              _fieldTile(icon: Icons.radio_button_unchecked,
                  hint: 'Indiquez votre position',
                  value: _gettingLocation ? 'Localisation en cours...' : selectedPosition,
                  onTap: _gettingLocation ? () {} : _showPositionPicker,
                  trailing: _gettingLocation
                      ? Container(width: 34, height: 34, padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(10)),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 18))),
              const SizedBox(height: 12),
              _fieldTile(icon: Icons.radio_button_unchecked, hint: "Volume d'eau",
                  value: selectedVolume, onTap: _showVolumePicker,
                  trailing: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.local_shipping, color: Colors.white, size: 18))),
              const SizedBox(height: 12),
              _fieldTile(icon: Icons.radio_button_unchecked, hint: 'Choisir un fournisseur',
                  value: selectedFournisseur?.nom, onTap: _showFournisseurPicker,
                  trailing: Stack(alignment: Alignment.topRight, children: [
                    Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person, color: Colors.white, size: 18)),
                    if (_loadingDrivers)
                      const Positioned(top: 0, right: 0,
                          child: SizedBox(width: 10, height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blue))),
                  ])),
            ]),
          ),

          const Spacer(),

          // Selected driver summary
          if (selectedFournisseur != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${selectedFournisseur!.nom}  •  ${selectedFournisseur!.available} L disponibles',
                  style: TextStyle(color: Colors.green.shade700,
                      fontWeight: FontWeight.w600, fontSize: 13),
                )),
              ]),
            ),

          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: (_canConfirm && !_submitting) ? _confirmOrder : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF),
              disabledBackgroundColor: Colors.black12,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Confirmer la commande',
                style: TextStyle(color: _canConfirm ? Colors.white : Colors.black38,
                    fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}