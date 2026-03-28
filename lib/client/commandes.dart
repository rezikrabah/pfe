import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:test2/client/client_tracking_page.dart';

import '../services/api_service.dart';

// ── Fournisseur model ─────────────────────────────────────────────────────────
class _Fournisseur {
  final String id;
  final String nom;
  _Fournisseur({required this.id, required this.nom});

  factory _Fournisseur.fromJson(Map<String, dynamic> j) => _Fournisseur(
    id:  (j['_id'] ?? j['id'] ?? '').toString(),
    nom: '${j['prenom'] ?? ''} ${j['nom'] ?? ''}'.trim().isNotEmpty
        ? '${j['prenom'] ?? ''} ${j['nom'] ?? ''}'.trim()
        : j['email'] ?? 'Fournisseur',
  );
}

class commandes extends StatefulWidget {
  final int clientId;
  const commandes({super.key, required this.clientId});

  @override
  State<commandes> createState() => _CommandesState();
}

class _CommandesState extends State<commandes> {
  String?       selectedPosition;
  String?       selectedVolume;
  _Fournisseur? selectedFournisseur;
  bool          _submitting      = false;
  bool          _gettingLocation = false;
  double?       _selectedLat;
  double?       _selectedLon;

  List<_Fournisseur> _fournisseurs  = [];
  bool               _loadingFourn  = false;
  String?            _fournError;

  final List<String> volumes = [
    '100L', '500L', '1000L', '2 000L', '3 000 L', '5 000 L',
  ];

  @override
  void initState() {
    super.initState();
    _debugFournisseurs();
    _loadFournisseurs();
  }

  // ── GPS ───────────────────────────────────────────────────
  Future<void> _useMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showError('Permission de localisation refusée.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _selectedLat     = pos.latitude;
        _selectedLon     = pos.longitude;
        selectedPosition =
        '📍 ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Position obtenue ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2)));
    } catch (_) {
      _showError('Impossible d\'obtenir la position GPS.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // ── Load fournisseurs via ApiService ──────────────────────
  Future<void> _loadFournisseurs() async {
    setState(() { _loadingFourn = true; _fournError = null; });

    final list = await ApiService.getFournisseurs();
    print('RAW FOURNISSEURS: $list'); // ← check field names

    setState(() {
      _loadingFourn = false;
      if (list.isNotEmpty) {
        _fournisseurs = list.map((e) => _Fournisseur.fromJson(e)).toList();
      } else {
        // ✅ Don't show error icon — show clean empty state
        _fournisseurs = [];
        _fournError = null; // let _buildNoFourn() handle it
      }
    });
  }

  int _parseVolume(String vol) =>
      int.tryParse(vol.replaceAll(' ', '').replaceAll('L', '')) ?? 0;

  // ── Submit order via ApiService ───────────────────────────
  Future<void> _confirmOrder() async {
    if (!_canConfirm) return;
    setState(() => _submitting = true);
    try {
      final demand = _parseVolume(selectedVolume!);

          final result = await ApiService.addCommande(
      capacite: demand.toDouble(),
          prix: demand.toDouble() * 2,
            lat:      _selectedLat,
            lon:      _selectedLon,
          );
      print('ADD COMMANDE RESULT: $result');

      if (result['error'] != null) {
        _showError(result['error']);
        return;
      }

      final orderId = (result['_id'] ?? result['id'] ?? result['commandeId'] ?? '').toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Commande envoyée ✓  —  ${selectedFournisseur!.nom}'),
          backgroundColor: const Color(0xFF2979FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));

        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ClientTrackingPage(
            commandeId: orderId,
            // ✅ Use ApiService.userId instead of hardcoded widget.clientId
            clientId: ApiService.userId ?? widget.clientId.toString(),
          ),
        ));
      }
    } catch (_) {
      _showError('Erreur réseau.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
  Future<void> _debugFournisseurs() async {
    print('=== DEBUG FOURNISSEURS ===');
    print('Token: ${ApiService.token}');

    final res = await http.get(
      Uri.parse('https://pfe-backend-nwmy.onrender.com/api/clients/fournisseurs'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiService.token}',
      },
    );

    print('Status: ${res.statusCode}');
    print('Body: ${res.body}');
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                _handle(), const SizedBox(height: 12),
                const Text('Indiquez votre position',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF0C2A34))),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl, autofocus: true,
                  style: const TextStyle(color: Color(0xFF1A237E)),
                  decoration: InputDecoration(
                    hintText: 'Ex: EL HARRACH, ALGER',
                    hintStyle: const TextStyle(color: Colors.black38),
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF2979FF)),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                    if (ctrl.text.trim().isNotEmpty)
                      setState(() => selectedPosition = ctrl.text.trim());
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Confirmer',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
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
                    Icon(Icons.water_drop,
                        color: isSel ? Colors.white : const Color(0xFF2979FF)),
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
            const SizedBox(height: 12), _handle(), const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Choisir un fournisseur',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E))),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF2979FF)),
                  onPressed: () {
                    Navigator.pop(context);
                    _loadFournisseurs().then((_) => _showFournisseurPicker());
                  },
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loadingFourn
                  ? const Center(child: CircularProgressIndicator())
                  : _fournError != null
                  ? _buildFournError()
                  : _fournisseurs.isEmpty
                  ? _buildNoFourn()
                  : ListView.builder(
                itemCount: _fournisseurs.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (_, i) {
                  final f = _fournisseurs[i];
                  return _buildFournTile(f, selectedFournisseur?.id == f.id);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────

  Widget _buildFournTile(_Fournisseur f, bool isSel) => GestureDetector(
    onTap: () { setState(() => selectedFournisseur = f); Navigator.pop(context); },
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSel ? const Color(0xFF2979FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSel ? const Color(0xFF2979FF) : Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: isSel ? Colors.white24 : const Color(0xFF0C2A34),
          child: Icon(Icons.store, color: isSel ? Colors.white : const Color(0xFF2979FF)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(f.nom,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                color: isSel ? Colors.white : const Color(0xFF1A237E)))),
        if (isSel) const Icon(Icons.check_circle, color: Colors.white),
      ]),
    ),
  );

  Widget _buildFournError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 12),
      Text(_fournError!, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          _loadFournisseurs().then((_) => _showFournisseurPicker());
        },
        icon: const Icon(Icons.refresh), label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white),
      ),
    ]),
  ));

  Widget _buildNoFourn() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.store_mall_directory_outlined, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 12),
      Text('Aucun fournisseur disponible',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
      const SizedBox(height: 8),
      Text('Aucun fournisseur enregistré pour l\'instant.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
    ]),
  ));

  Widget _handle() => Center(child: Container(width: 40, height: 4,
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))));

  Widget _quickChip(String label, VoidCallback onTap) => ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E))),
    backgroundColor: Colors.white, side: const BorderSide(color: Colors.black12),
    onPressed: onTap,
  );

  Widget _fieldTile({required IconData icon, required String hint, required String? value,
    required Widget trailing, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
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

  bool get _canConfirm =>
      selectedPosition != null && selectedVolume != null && selectedFournisseur != null;

  // ── BUILD ─────────────────────────────────────────────────

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
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12)),
            child: Column(children: [
              _fieldTile(
                icon: Icons.radio_button_unchecked,
                hint: 'Indiquez votre position',
                value: _gettingLocation ? 'Localisation en cours...' : selectedPosition,
                onTap: _gettingLocation ? () {} : _showPositionPicker,
                trailing: _gettingLocation
                    ? Container(width: 34, height: 34, padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10)),
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 18)),
              ),
              const SizedBox(height: 12),
              _fieldTile(
                icon: Icons.radio_button_unchecked, hint: "Volume d'eau",
                value: selectedVolume, onTap: _showVolumePicker,
                trailing: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.water_drop, color: Colors.white, size: 18)),
              ),
              const SizedBox(height: 12),
              _fieldTile(
                icon: Icons.radio_button_unchecked, hint: 'Choisir un fournisseur',
                value: selectedFournisseur?.nom, onTap: _showFournisseurPicker,
                trailing: Stack(alignment: Alignment.topRight, children: [
                  Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1A237E),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.store, color: Colors.white, size: 18)),
                  if (_loadingFourn)
                    const Positioned(top: 0, right: 0,
                        child: SizedBox(width: 10, height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blue))),
                ]),
              ),
            ]),
          ),

          const Spacer(),

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
                Expanded(child: Text('Fournisseur : ${selectedFournisseur!.nom}',
                    style: TextStyle(color: Colors.green.shade700,
                        fontWeight: FontWeight.w600, fontSize: 13))),
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