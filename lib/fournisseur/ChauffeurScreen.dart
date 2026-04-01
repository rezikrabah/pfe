import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChauffeurScreen extends StatefulWidget {
  const ChauffeurScreen({Key? key}) : super(key: key);

  @override
  State<ChauffeurScreen> createState() => _ChauffeurScreenState();
}

class _ChauffeurScreenState extends State<ChauffeurScreen> {
  List<dynamic> _chauffeurs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChauffeurs();
  }

  Future<void> _loadChauffeurs() async {
    setState(() => _loading = true);
    final data = await ApiService.getMyChauffeurs();
    print('CHAUFFEURS: $data');
    setState(() {
      _chauffeurs = data;
      _loading    = false;
    });
  }

  // ── Add chauffeur bottom sheet ─────────────────────────────
  void _showAddDialog() {
    final nomCtrl      = TextEditingController();
    final prenomCtrl   = TextEditingController();
    final telCtrl      = TextEditingController();
    final adresseCtrl  = TextEditingController();
    final capaciteCtrl = TextEditingController();
    final formKey      = GlobalKey<FormState>();
    bool submitting    = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Handle
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 16),
                  const Text('Ajouter un chauffeur',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 20),

                  // ✅ Nom
                  TextFormField(
                    controller: nomCtrl,
                    decoration: _inputDeco('Nom', Icons.badge),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),

                  // ✅ Prenom
                  TextFormField(
                    controller: prenomCtrl,
                    decoration: _inputDeco('Prénom', Icons.person),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),

                  // ✅ Telephone
                  TextFormField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDeco('Téléphone', Icons.phone),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),

                  // ✅ Adresse
                  TextFormField(
                    controller: adresseCtrl,
                    decoration: _inputDeco('Adresse', Icons.location_on),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),

                  // ✅ Capacite camion
                  TextFormField(
                    controller: capaciteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('Capacité camion (L)', Icons.local_shipping),
                    validator: (v) {
                      if (v!.isEmpty) return 'Requis';
                      if (double.tryParse(v) == null) return 'Nombre invalide';
                      if (double.parse(v) <= 0) return 'Doit être > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => submitting = true);

                        // ✅ Pass all 5 fields to ApiService
                        final result = await ApiService.addChauffeur(
                          nom:            nomCtrl.text.trim(),
                          prenom:         prenomCtrl.text.trim(),
                          telephone:      telCtrl.text.trim(),
                          adresse:        adresseCtrl.text.trim(),
                          capaciteCamion: double.parse(capaciteCtrl.text.trim()),


                        );

                        print('ADD CHAUFFEUR RESULT: $result');
                        setModalState(() => submitting = false);

                        if (result['error'] != null ||
                            (result['msg'] != null &&
                                result['msg'].toString().contains('obligatoires'))) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result['error'] ?? result['msg']),
                            backgroundColor: Colors.red,
                          ));
                        } else {
                          Navigator.pop(context);
                          _loadChauffeurs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chauffeur ajouté ✓'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: submitting
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Text('Ajouter',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A)),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
  );

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes Chauffeurs'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChauffeurs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter chauffeur',
            style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chauffeurs.isEmpty
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Aucun chauffeur',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Ajoutez votre premier chauffeur',
              style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white),
          ),
        ],
      ))
          : RefreshIndicator(
        onRefresh: _loadChauffeurs,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _chauffeurs.length,
          itemBuilder: (_, i) =>
              _buildChauffeurCard(_chauffeurs[i]),
        ),
      ),
    );
  }

  Widget _buildChauffeurCard(Map<String, dynamic> c) {
    final nom      = c['nom']    ?? '';
    final prenom   = c['prenom'] ?? '';
    final tel      = c['telephone'] ?? '-';
    final adresse  = c['adresse']   ?? '-';
    final capacite = (c['capaciteCamion'] as num?)?.toDouble() ?? 0.0;
    final disponible = c['disponible'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(
            color: disponible ? Colors.green : Colors.orange, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
          radius: 24,
          child: const Icon(Icons.person, color: Color(0xFF1E3A8A), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$prenom $nom',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(tel, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(adresse,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.local_shipping, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text('${capacite.toStringAsFixed(0)} L',
                  style: const TextStyle(color: Colors.blue, fontSize: 13)),
            ]),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: disponible
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            disponible ? 'Disponible' : 'Occupé',
            style: TextStyle(
                color: disponible ? Colors.green : Colors.orange,
                fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }
}