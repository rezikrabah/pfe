import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test2/fournisseur/provider_home_screen_FINAL.dart';
import 'package:test2/services/api_service.dart';
import 'package:test2/fournisseur/ChauffeurScreen.dart';
// ─── Abonnement plans ───────────────────────────────────────────
class _Plan {
  final String id;
  final String label;
  final String price;
  final String duration;
  final String description;
  final IconData icon;
  final Color color;

  const _Plan({
    required this.id,
    required this.label,
    required this.price,
    required this.duration,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<_Plan> _plans = [
  _Plan(
    id: 'mensuel',
    label: 'Mensuel',
    price: '15 000 DA',
    duration: '1 mois',
    description: 'Idéal pour démarrer',
    icon: Icons.calendar_month,
    color: Color(0xFF2979FF),
  ),
  _Plan(
    id: 'trimestriel',
    label: 'Trimestriel',
    price: '40 000 DA',
    duration: '3 mois',
    description: 'Économisez 5 000 DA',
    icon: Icons.calendar_today,
    color: Color(0xFF00897B),
  ),
  _Plan(
    id: 'annuel',
    label: 'Annuel',
    price: '140 000 DA',
    duration: '12 mois',
    description: 'Meilleure offre — 2 mois offerts',
    icon: Icons.workspace_premium,
    color: Color(0xFFE65100),
  ),
];

// ─── Reference code generator ─────────────────────────────────
String _generateRef(String planId) {
  final rng = Random();
  final nums = List.generate(8, (_) => rng.nextInt(10)).join();
  return 'ABO-${planId.toUpperCase().substring(0, 3)}-$nums';
}

class fournisseurinfos extends StatefulWidget {
  final String role;
  const fournisseurinfos({super.key, this.role = 'chauffeur'});

  @override
  State<fournisseurinfos> createState() => _fournisseurinfosState();
}

class _fournisseurinfosState extends State<fournisseurinfos> {
  List<String> selectedwilayas = [];
  String? selectedVolume;
  String? selectedPlanId;
  String? _referenceCode;
  bool _submitting = false;

  final TextEditingController _permitCtrl = TextEditingController();

  @override
  void dispose() {
    _permitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canConfirm) return;
    setState(() => _submitting = true);

    try {
      final result = await ApiService.addFournisseurInfo(
        quantiteEau: double.tryParse(
            selectedVolume!.replaceAll(' L', '').replaceAll(' ', '').trim()) ??
            0,
        wilayas: selectedwilayas,
        // Pass these two new fields — add them to ApiService.addFournisseurInfo()
        numeroPremit: _permitCtrl.text.trim(),
        abonnement: selectedPlanId,
        refPaiement: _referenceCode,
      );

      if (result['error'] != null) {
        _showError(result['error']);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Informations enregistrées ✓'),
            backgroundColor: const Color(0xFF2979FF),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) {
            if (widget.role == 'gerant') return const ChauffeurScreen();
            return const ProviderHomeScreen();
          }),
        );
      }
    } catch (e) {
      _showError('Erreur réseau. Réessayez.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Wilaya Picker ──────────────────────────────────────────────
  final List<String> wilaya = [
    '01 - Adrar', '02 - Chlef', '03 - Laghouat', '04 - Oum El Bouaghi',
    '05 - Batna', '06 - Béjaïa', '07 - Biskra', '08 - Béchar',
    '09 - Blida', '10 - Bouira', '11 - Tamanrasset', '12 - Tébessa',
    '13 - Tlemcen', '14 - Tiaret', '15 - Tizi Ouzou', '16 - Alger',
    '17 - Djelfa', '18 - Jijel', '19 - Sétif', '20 - Saïda',
    '21 - Skikda', '22 - Sidi Bel Abbès', '23 - Annaba', '24 - Guelma',
    '25 - Constantine', '26 - Médéa', '27 - Mostaganem', '28 - M\'Sila',
    '29 - Mascara', '30 - Ouargla', '31 - Oran', '32 - El Bayadh',
    '33 - Illizi', '34 - Bordj Bou Arréridj', '35 - Boumerdès',
    '36 - El Tarf', '37 - Tindouf', '38 - Tissemsilt', '39 - El Oued',
    '40 - Khenchela', '41 - Souk Ahras', '42 - Tipaza', '43 - Mila',
    '44 - Aïn Defla', '45 - Naâma', '46 - Aïn Témouchent', '47 - Ghardaïa',
    '48 - Relizane', '49 - Timimoun', '50 - Bordj Badji Mokhtar',
    '51 - Ouled Djellal', '52 - Béni Abbès', '53 - In Salah',
    '54 - In Guezzam', '55 - Touggourt', '56 - Djanet',
    '57 - El M\'Ghair', '58 - El Meniaa',
  ];

  void _showwilayaPicker() {
    List<String> tempSelected = List.from(selectedwilayas);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: screenHeight * 0.55,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            SizedBox(height: screenHeight * 0.015),
            _handle(),
            SizedBox(height: screenHeight * 0.015),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Wilayas",
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A237E),
                  )),
              if (tempSelected.isNotEmpty) ...[
                SizedBox(width: screenWidth * 0.02),
                CircleAvatar(
                  radius: screenWidth * 0.028,
                  backgroundColor: const Color(0xFF2979FF),
                  child: Text('${tempSelected.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ]
            ]),
            SizedBox(height: screenHeight * 0.015),
            Expanded(
              child: ListView.builder(
                itemCount: wilaya.length,
                padding:
                EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                itemBuilder: (context, index) {
                  final w = wilaya[index];
                  final isSelected = tempSelected.contains(w);
                  return GestureDetector(
                    onTap: () => setModalState(() {
                      isSelected
                          ? tempSelected.remove(w)
                          : tempSelected.add(w);
                    }),
                    child: Container(
                      margin: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.006),
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.05,
                        vertical: screenHeight * 0.016,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2979FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2979FF)
                              : Colors.black12,
                        ),
                      ),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: screenWidth * 0.055,
                          height: screenWidth * 0.055,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black26,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: isSelected
                              ? Icon(Icons.check,
                              size: screenWidth * 0.035,
                              color: const Color(0xFF2979FF))
                              : null,
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Icon(Icons.map_outlined,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF2979FF),
                            size: screenWidth * 0.055),
                        SizedBox(width: screenWidth * 0.035),
                        Text(w,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1A237E),
                            )),
                      ]),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.04,
                screenHeight * 0.01,
                screenWidth * 0.04,
                screenHeight * 0.02,
              ),
              child: SizedBox(
                width: double.infinity,
                height: screenHeight * 0.065,
                child: ElevatedButton(
                  onPressed: tempSelected.isEmpty
                      ? null
                      : () {
                    setState(() =>
                    selectedwilayas = List.from(tempSelected));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    disabledBackgroundColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    tempSelected.isEmpty
                        ? 'Sélectionner au moins une'
                        : 'Confirmer (${tempSelected.length})',
                    style: TextStyle(
                      color: tempSelected.isEmpty
                          ? Colors.black38
                          : Colors.white,
                      fontSize: screenWidth * 0.038,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Volume Picker ──────────────────────────────────────────────
  void _showVolumePicker() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final ctrl = TextEditingController(
      text: selectedVolume?.replaceAll(' L', '') ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.06),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _handle(),
            SizedBox(height: screenHeight * 0.02),
            Text("Volume d'eau disponible",
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A237E),
                )),
            SizedBox(height: screenHeight * 0.01),
            Text("Entrez la quantité exacte en litres",
                style: TextStyle(
                    color: Colors.black54, fontSize: screenWidth * 0.033)),
            SizedBox(height: screenHeight * 0.025),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: const Color(0xFF1A237E),
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Ex: 2000',
                hintStyle: const TextStyle(color: Colors.black26),
                suffixText: 'L',
                suffixStyle: TextStyle(
                  color: const Color(0xFF2979FF),
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.065,
              child: ElevatedButton(
                onPressed: () {
                  final val = int.tryParse(ctrl.text.trim());
                  if (val != null && val > 0) {
                    setState(() => selectedVolume = '$val L');
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2979FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Confirmer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
          ]),
        ),
      ),
    );
  }

  // ── Abonnement picker sheet ────────────────────────────────────
  void _showAbonnementPicker() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.04,
          0,
          screenWidth * 0.04,
          screenHeight * 0.03,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: screenHeight * 0.015),
            _handle(),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'Choisir un abonnement',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: screenHeight * 0.005),
            Text(
              'Paiement en agence / CCP / Baridimob',
              style: TextStyle(
                fontSize: screenWidth * 0.033,
                color: Colors.black45,
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            ..._plans.map((plan) => _PlanCard(
              plan: plan,
              isSelected: selectedPlanId == plan.id,
              onTap: () {
                setState(() {
                  selectedPlanId = plan.id;
                  _referenceCode = _generateRef(plan.id);
                });
                Navigator.pop(context);
                // Show payment instructions right after selection
                Future.delayed(
                  const Duration(milliseconds: 200),
                      () => _showPaymentInstructions(),
                );
              },
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            )),
          ],
        ),
      ),
    );
  }

  // ── Payment instructions dialog ────────────────────────────────
  void _showPaymentInstructions() {
    if (_referenceCode == null || selectedPlanId == null) return;
    final plan = _plans.firstWhere((p) => p.id == selectedPlanId);
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
      shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                width: screenWidth * 0.15,
                height: screenWidth * 0.15,
                decoration: BoxDecoration(
                  color: plan.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long,
                    color: plan.color, size: screenWidth * 0.07),
              ),
              SizedBox(height: screenWidth * 0.04),
              Text(
                'Instructions de paiement',
                style: TextStyle(
                  fontSize: screenWidth * 0.042,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: screenWidth * 0.02),

              // ── Steps ──
              _InstructionStep(
                number: '1',
                text:
                'Rendez-vous dans une agence Algérie Poste ou utilisez Baridimob / CCP.',
                screenWidth: screenWidth,
              ),
              _InstructionStep(
                number: '2',
                text:
                'Effectuez un virement de ${plan.price} vers le CCP : 0012345678 (AquaLogistiq).',
                screenWidth: screenWidth,
              ),
              _InstructionStep(
                number: '3',
                text:
                'Indiquez cette référence dans le motif du virement :',
                screenWidth: screenWidth,
              ),

              // ── Reference code ──
              Container(
                margin:
                EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenWidth * 0.035,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: plan.color.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _referenceCode!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: plan.color,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      color: plan.color,
                      tooltip: 'Copier',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _referenceCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Référence copiée ✓'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              _InstructionStep(
                number: '4',
                text:
                'Après paiement, votre compte sera activé sous 24 h ouvrables.',
                screenWidth: screenWidth,
              ),

              SizedBox(height: screenWidth * 0.04),

              // ── Close ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan.color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(
                        vertical: screenWidth * 0.035),
                  ),
                  child: Text(
                    'J\'ai compris',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.038,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _fieldTile({
    required IconData icon,
    required String hint,
    required String? value,
    required Widget trailing,
    required VoidCallback onTap,
    required double screenWidth,
    required double screenHeight,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.02,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(children: [
            Icon(icon,
                color: value != null
                    ? const Color(0xFF2979FF)
                    : Colors.black38,
                size: screenWidth * 0.055),
            SizedBox(width: screenWidth * 0.035),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  color: value != null
                      ? const Color(0xFF1A237E)
                      : Colors.black38,
                  fontSize: screenWidth * 0.038,
                  fontWeight: value != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            trailing,
          ]),
        ),
      );

  bool get _canConfirm =>
      selectedwilayas.isNotEmpty &&
          selectedVolume != null &&
          _permitCtrl.text.trim().isNotEmpty &&
          selectedPlanId != null;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final selectedPlan = selectedPlanId != null
        ? _plans.firstWhere((p) => p.id == selectedPlanId)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF),
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A237E)),
        title: Text(
          'Informations fournisseur',
          style: TextStyle(
            color: const Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.043,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.04),
            child: Icon(Icons.water_drop,
                color: Colors.blue.shade900,
                size: screenWidth * 0.065),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Section: Informations générales ───────────────────
          _sectionLabel('Informations générales', screenWidth),
          SizedBox(height: screenHeight * 0.01),
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(children: [
              // Wilaya picker
              _fieldTile(
                icon: Icons.radio_button_unchecked,
                hint: "Wilayas desservies",
                value: selectedwilayas.isEmpty
                    ? null
                    : '${selectedwilayas.length} wilaya(s) sélectionnée(s)',
                onTap: _showwilayaPicker,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                trailing: Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.map,
                      color: Colors.white, size: screenWidth * 0.045),
                ),
              ),

              SizedBox(height: screenHeight * 0.015),

              // Volume picker
              _fieldTile(
                icon: Icons.radio_button_unchecked,
                hint: "Volume d'eau disponible",
                value: selectedVolume,
                onTap: _showVolumePicker,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                trailing: Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_shipping,
                      color: Colors.white, size: screenWidth * 0.045),
                ),
              ),

              SizedBox(height: screenHeight * 0.015),

              // ── Permit number text field ──────────────────────
              TextField(
                controller: _permitCtrl,
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: TextStyle(
                  color: const Color(0xFF1A237E),
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Numéro de permis (ex: ALG-2024-00123)',
                  hintStyle: TextStyle(
                    color: Colors.black38,
                    fontSize: screenWidth * 0.036,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                    color: _permitCtrl.text.trim().isNotEmpty
                        ? const Color(0xFF2979FF)
                        : Colors.black38,
                    size: screenWidth * 0.055,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: Color(0xFF2979FF), width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenHeight * 0.02,
                  ),
                ),
              ),
            ]),
          ),

          SizedBox(height: screenHeight * 0.025),

          // ── Section: Abonnement ───────────────────────────────
          _sectionLabel('Abonnement', screenWidth),
          SizedBox(height: screenHeight * 0.01),

          GestureDetector(
            onTap: _showAbonnementPicker,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedPlan != null
                      ? selectedPlan.color.withOpacity(0.4)
                      : Colors.black12,
                  width: selectedPlan != null ? 1.5 : 1,
                ),
              ),
              child: selectedPlan == null
              // ── Empty state ──
                  ? Row(children: [
                Container(
                  width: screenWidth * 0.12,
                  height: screenWidth * 0.12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.card_membership,
                      color: Colors.black38,
                      size: screenWidth * 0.055),
                ),
                SizedBox(width: screenWidth * 0.035),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choisir un abonnement',
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              color: Colors.black38,
                            )),
                        Text('Mensuel, trimestriel ou annuel',
                            style: TextStyle(
                              fontSize: screenWidth * 0.032,
                              color: Colors.black26,
                            )),
                      ]),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.black26,
                    size: screenWidth * 0.055),
              ])
              // ── Selected plan summary ──
                  : Row(children: [
                Container(
                  width: screenWidth * 0.12,
                  height: screenWidth * 0.12,
                  decoration: BoxDecoration(
                    color: selectedPlan.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(selectedPlan.icon,
                      color: selectedPlan.color,
                      size: screenWidth * 0.055),
                ),
                SizedBox(width: screenWidth * 0.035),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedPlan.label,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A237E),
                            )),
                        Text(
                            '${selectedPlan.price} · ${selectedPlan.duration}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.033,
                              color: selectedPlan.color,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                ),
                // Reference code badge
                if (_referenceCode != null)
                  GestureDetector(
                    onTap: _showPaymentInstructions,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.025,
                        vertical: screenWidth * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color:
                        selectedPlan.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selectedPlan.color
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_outlined,
                                size: screenWidth * 0.035,
                                color: selectedPlan.color),
                            SizedBox(width: screenWidth * 0.01),
                            Text('Réf',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  color: selectedPlan.color,
                                  fontWeight: FontWeight.bold,
                                )),
                          ]),
                    ),
                  ),
              ]),
            ),
          ),

          // ── Pending badge ─────────────────────────────────────
          if (selectedPlanId != null) ...[
            SizedBox(height: screenHeight * 0.012),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.03,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.access_time,
                    color: Colors.orange.shade700,
                    size: screenWidth * 0.045),
                SizedBox(width: screenWidth * 0.025),
                Expanded(
                  child: Text(
                    'En attente de confirmation du paiement. Votre compte sera activé sous 24 h après réception.',
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ]),
            ),
          ],

          SizedBox(height: screenHeight * 0.04),

          // ── Confirm button ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: screenHeight * 0.07,
            child: ElevatedButton(
              onPressed: (_canConfirm && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                disabledBackgroundColor: Colors.black12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? SizedBox(
                height: screenWidth * 0.05,
                width: screenWidth * 0.05,
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Text(
                'Confirmer',
                style: TextStyle(
                  color:
                  _canConfirm ? Colors.white : Colors.black38,
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.02),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text, double screenWidth) => Padding(
    padding: EdgeInsets.only(left: screenWidth * 0.01),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: screenWidth * 0.03,
        fontWeight: FontWeight.w700,
        color: Colors.black38,
        letterSpacing: 1.1,
      ),
    ),
  );
}

// ─── Plan card widget ──────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final double screenWidth;
  final double screenHeight;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: screenHeight * 0.012),
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: isSelected ? plan.color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? plan.color : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: screenWidth * 0.12,
            height: screenWidth * 0.12,
            decoration: BoxDecoration(
              color: plan.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(plan.icon,
                color: plan.color, size: screenWidth * 0.055),
          ),
          SizedBox(width: screenWidth * 0.035),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(plan.label,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        )),
                    SizedBox(width: screenWidth * 0.02),
                    if (plan.id == 'annuel')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: plan.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Populaire',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.025,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                  ]),
                  SizedBox(height: 2),
                  Text(plan.description,
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: Colors.black45,
                      )),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(plan.price,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.bold,
                  color: plan.color,
                )),
            Text(plan.duration,
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.black38,
                )),
          ]),
        ]),
      ),
    );
  }
}

// ─── Instruction step widget ────────────────────────────────────
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  final double screenWidth;

  const _InstructionStep({
    required this.number,
    required this.text,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.015),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: screenWidth * 0.065,
          height: screenWidth * 0.065,
          decoration: const BoxDecoration(
            color: Color(0xFF1A237E),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.032,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
        SizedBox(width: screenWidth * 0.03),
        Expanded(
          child: Text(text,
              style: TextStyle(
                fontSize: screenWidth * 0.034,
                color: Colors.black87,
                height: 1.4,
              )),
        ),
      ]),
    );
  }
}