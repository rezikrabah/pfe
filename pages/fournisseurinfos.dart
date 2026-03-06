import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test2/pages/RoleSelectionScreen.dart';

void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: fournisseurinfos(),
    )
);
class fournisseurinfos extends StatefulWidget {

  const fournisseurinfos({super.key});

  @override
  State<fournisseurinfos> createState() => _fournisseurinfosState();
}

class _fournisseurinfosState extends State<fournisseurinfos> {
  @override
  Widget build(BuildContext context) {
    return
        Scaffold(
          backgroundColor: Color(0xFF0B3C49),
          appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),title: const Text("fournisseurinfos",style: TextStyle(color: Color(0xFFEAFBFF) ,fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 2,),),backgroundColor: Color(0xFF0B3C49),centerTitle: true,
            actions: [
              IconButton(
                icon: const     Icon(Icons.water_drop, size: 30,color: Color(0xFF1E88E5)),
                onPressed: () {

                },
              ),
            ],
          ),

          body: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'wilaya',
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  hintText: 'enter your name',
                  hintStyle:   const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,

                  ),
                  prefixIcon:IconButton(  icon:const Icon(CupertinoIcons.arrow_right,color: Colors.white,size: 20,),
                    onPressed: (){

                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                  ),
                  // Border when focused
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),

                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'nomber du camions',
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  hintText: 'enter your name',
                  hintStyle:   const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,

                  ),
                  prefixIcon:const  Icon(Icons.badge,color: Colors.white,),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                  ),
                  // Border when focused
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
                style: TextStyle(
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'permis',
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  hintText: 'enter your name',
                  hintStyle:   const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,

                  ),
                  prefixIcon:const  Icon(Icons.badge,color: Colors.white,),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                  ),
                  // Border when focused
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 40,),
              Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child:TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoleSelectionScreen(),
                      ),
                    );
                  },
                  label:  const Text(
                    'sign up',style:TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.w600),
                  ),
                ),

              ),
            ],
          ),
    );
  }
}
const List<String> algeriaWilayas = [
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

/// Call this function to show the wilaya picker.
/// Returns the selected wilaya string, or null if dismissed.
///
/// Example usage:
/// ```dart
/// final result = await showWilayaPicker(context, selectedWilaya: selectedWilaya);
/// if (result != null) setState(() => selectedWilaya = result);
/// ```
Future<String?> showWilayaPicker(
    BuildContext context, {
      String? selectedWilaya,
    }) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _WilayaPickerSheet(selectedWilaya: selectedWilaya),
  );
}

class _WilayaPickerSheet extends StatefulWidget {
  final String? selectedWilaya;
  const _WilayaPickerSheet({this.selectedWilaya});

  @override
  State<_WilayaPickerSheet> createState() => _WilayaPickerSheetState();
}

class _WilayaPickerSheetState extends State<_WilayaPickerSheet> {
  List<String> filtered = List.from(algeriaWilayas);
  final TextEditingController _searchController = TextEditingController();

  void _onSearch(String query) {
    setState(() {
      filtered = algeriaWilayas
          .where((w) => w.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0D3B38),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Choisir une wilaya',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher une wilaya...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
              child: Text(
                'Aucune wilaya trouvée',
                style: TextStyle(color: Colors.white54),
              ),
            )
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final wilaya = filtered[index];
                final isSelected = wilaya == widget.selectedWilaya;

                return ListTile(
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: isSelected
                        ? const Color(0xFF4FC3F7)
                        : Colors.white54,
                  ),
                  title: Text(
                    wilaya,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF4FC3F7)
                          : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                      color: Color(0xFF4FC3F7))
                      : null,
                  onTap: () => Navigator.pop(context, wilaya),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
