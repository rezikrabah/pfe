import 'package:flutter/material.dart';


import '../fournisseur/profile_screen.dart';
import '../fournisseur/provider_home_screen_FINAL.dart';
class fournisseurinfos extends StatefulWidget {
  const fournisseurinfos({super.key});

  @override
  State<fournisseurinfos> createState() => _fournisseurinfosState();
}

class _fournisseurinfosState extends State<fournisseurinfos> {
  List<String> selectedwilayas = [];
  String? selectedVolume;
  final List<String> wilaya = [
    '01 - Adrar',
    '02 - Chlef',
    '03 - Laghouat',
    '04 - Oum El Bouaghi',
    '05 - Batna',
    '06 - Béjaïa',
    '07 - Biskra',
    '08 - Béchar',
    '09 - Blida',
    '10 - Bouira',
    '11 - Tamanrasset',
    '12 - Tébessa',
    '13 - Tlemcen',
    '14 - Tiaret',
    '15 - Tizi Ouzou',
    '16 - Alger',
    '17 - Djelfa',
    '18 - Jijel',
    '19 - Sétif',
    '20 - Saïda',
    '21 - Skikda',
    '22 - Sidi Bel Abbès',
    '23 - Annaba',
    '24 - Guelma',
    '25 - Constantine',
    '26 - Médéa',
    '27 - Mostaganem',
    '28 - M\'Sila',
    '29 - Mascara',
    '30 - Ouargla',
    '31 - Oran',
    '32 - El Bayadh',
    '33 - Illizi',
    '34 - Bordj Bou Arréridj',
    '35 - Boumerdès',
    '36 - El Tarf',
    '37 - Tindouf',
    '38 - Tissemsilt',
    '39 - El Oued',
    '40 - Khenchela',
    '41 - Souk Ahras',
    '42 - Tipaza',
    '43 - Mila',
    '44 - Aïn Defla',
    '45 - Naâma',
    '46 - Aïn Témouchent',
    '47 - Ghardaïa',
    '48 - Relizane',
    '49 - Timimoun',
    '50 - Bordj Badji Mokhtar',
    '51 - Ouled Djellal',
    '52 - Béni Abbès',
    '53 - In Salah',
    '54 - In Guezzam',
    '55 - Touggourt',
    '56 - Djanet',
    '57 - El M\'Ghair',
    '58 - El Meniaa',
  ];


  final List<String> volumes = [
    '500-1000 L',
    '1 000-2000 L',
    '2 000-3000 L',
    '3 000++ L',

  ];

  // --- Position Picker ---
  void _showwilayaPicker() {
    List<String> tempSelected = List.from(selectedwilayas); // copie temporaire

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(  // <-- important pour mettre à jour l'intérieur
        builder: (context, setModalState) => Container(
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
              // Titre + badge compteur
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("wilayas",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  if (tempSelected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: const Color(0xFF2979FF),
                      child: Text('${tempSelected.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: wilaya.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final w = wilaya[index];
                    final isSelected = tempSelected.contains(w); // <-- contains au lieu de ==
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {  // <-- setModalState pas setState
                          if (isSelected) {
                            tempSelected.remove(w); // décocher
                          } else {
                            tempSelected.add(w);    // cocher
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2979FF) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSelected ? const Color(0xFF2979FF) : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            // Checkbox animé
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                border: Border.all(color: isSelected ? Colors.white : Colors.black26, width: 2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Color(0xFF2979FF))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.map_outlined, color: isSelected ? Colors.white : const Color(0xFF2979FF)),
                            const SizedBox(width: 14),
                            Text(w,
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF1A237E),
                                )),
                            const Spacer(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Bouton confirmer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: tempSelected.isEmpty ? null : () {
                      setState(() => selectedwilayas = List.from(tempSelected)); // applique au vrai état
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      disabledBackgroundColor: Colors.black12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      tempSelected.isEmpty ? 'Sélectionner au moins une' : 'Confirmer (${tempSelected.length})',
                      style: TextStyle(
                        color: tempSelected.isEmpty ? Colors.black38 : Colors.white,
                        fontSize: 15, fontWeight: FontWeight.bold,
                      ),
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
      selectedwilayas.isNotEmpty &&
          selectedVolume != null;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF),
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A237E)),
        title: const Text(
          'add this infos to login',
          style: TextStyle(
              color: Color(0xFF1A237E), fontWeight: FontWeight.bold,fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.water_drop, color: Colors.blue.shade900),
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

                  _fieldTile(
                    icon: Icons.radio_button_unchecked,
                    hint: "wilaya",
                    value: selectedwilayas.isEmpty
                        ? null
                        : '${selectedwilayas.length} wilaya(s) sélectionnée(s)',
                    onTap: _showwilayaPicker,
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.map,
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProviderHomeScreen()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ramzy khray',
                      ),
                      backgroundColor: const Color(0xFF2979FF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                  'login',
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