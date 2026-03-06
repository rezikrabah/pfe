import 'package:flutter/material.dart';
import 'package:test2/client/suivi.dart';

class commandes extends StatefulWidget {
  const commandes({super.key});

  @override
  State<commandes> createState() => Commandes();
}

class Commandes extends State<commandes> {
  String? selectedPosition;
  String? selectedVolume;
  String? selectedFournisseur;

  final List<Map<String, dynamic>> fournisseurs = [
    {'name': 'Fournisseur rezik rabah', 'numero telephone': '05541874241', 'volume deau': 500},
    {'name': 'Fournisseur naoui ramzy', 'numero telephone': '05521864241', 'volume deau': 3000},
    {'name': 'Fournisseur okbi wabil', 'numero telephone': '01234567891', 'volume deau': 100},
    {'name': 'Fournisseur locuif rafik', 'numero telephone': '0554181241', 'volume deau': 1500},
    {'name': 'Fournisseur mouhammed', 'numero telephone': '05541874241', 'volume deau': 2000},
    {'name': 'Fournisseur aissa', 'numero telephone': '05541874241', 'volume deau': 1200},
  ];

  final List<String> volumes = [
    '100 L',
    '500 L',
    '1000 L',
    '2 000 L',
    '3 000 L',
    '5 000 L',

  ];

  // --- Position Picker ---
  void _showPositionPicker() {
    final TextEditingController controller = TextEditingController(
      text: selectedPosition ?? '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              const SizedBox(height: 12),
              const Text(
                'Indiquez votre position',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C2A34),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF1A237E)),
                decoration: InputDecoration(
                  hintText: 'Ex: EL HARRACH.ALGER',
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(Icons.location_on_outlined,
                      color: Color(0xFF2979FF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Quick options
              Wrap(
                spacing: 8,
                children: [
                  _quickChip('📍 Ma position actuelle', () {
                    setState(() =>
                    selectedPosition = 'Ma position actuelle');
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(
                              () => selectedPosition = controller.text.trim());
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Confirmer',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Volume Picker ---
  void _showVolumePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _handle(),
            const SizedBox(height: 12),
            const Text(
              "Volume d'eau",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: volumes.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final vol = volumes[index];
                  final isSelected = vol == selectedVolume;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedVolume = vol);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
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
                      child: Row(
                        children: [
                          Icon(Icons.water_drop,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF2979FF)),
                          const SizedBox(width: 14),
                          Text(
                            vol,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1A237E),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Colors.white),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Fournisseur Picker ---
  void _showFournisseurPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _handle(),
            const SizedBox(height: 12),
            const Text(
              'Choisir un fournisseur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: fournisseurs.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final f = fournisseurs[index];
                  final isSelected = f['name'] == selectedFournisseur;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedFournisseur = f['name']);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2979FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2979FF)
                              : Colors.black12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.white24
                                : const Color(0xFF0C2A34),
                            child: Icon(Icons.local_shipping,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF2979FF)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1A237E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  f['numero telephone'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${f['volume deau']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF2979FF),
                                ),
                              ),
                              Text(
                                'Litre',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle,
                                color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
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

  Widget _quickChip(String label, VoidCallback onTap) => ActionChip(
    label: Text(label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E))),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Colors.black12),
    onPressed: onTap,
  );

  Widget _fieldTile({
    required IconData icon,
    required String hint,
    required String? value,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: value != null
                    ? const Color(0xFF2979FF)
                    : Colors.black38,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  color: value != null ? const Color(0xFF1A237E) : Colors.black38,
                  fontSize: 15,
                  fontWeight:
                  value != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  bool get _canConfirm =>
      selectedPosition != null &&
          selectedVolume != null &&
          selectedFournisseur != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF),
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A237E)),
        title: const Text(
          'commandes',
          style: TextStyle(
              color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.water_drop, color: Colors.blue.shade400),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  // Position
                  _fieldTile(
                    icon: Icons.radio_button_unchecked,
                    hint: 'Indiquez votre position',
                    value: selectedPosition,
                    onTap: _showPositionPicker,
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Volume
                  _fieldTile(
                    icon: Icons.radio_button_unchecked,
                    hint: "Volume d'eau",
                    value: selectedVolume,
                    onTap: _showVolumePicker,
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fournisseur
                  _fieldTile(
                    icon: Icons.radio_button_unchecked,
                    hint: 'Choisir un fournisseur',
                    value: selectedFournisseur,
                    onTap: _showFournisseurPicker,
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canConfirm
                    ? () {
                  // Handle order confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Commande confirmée ✓\n',
                      ),
                      backgroundColor: const Color(0xFF2979FF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => suivi(),
                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2979FF),
                  disabledBackgroundColor: Colors.black12,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'confirmée la commande',
                  style: TextStyle(
                    color: _canConfirm ? Colors.white : Colors.black38,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}