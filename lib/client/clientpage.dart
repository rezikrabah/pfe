import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test2/client/commandes.dart';
import 'package:test2/client/historique.dart';
import 'package:test2/client/profile.dart';
import 'package:test2/client/suivi.dart';
import '../services/api_service.dart';
import 'client_tracking_page.dart';

class clientpage extends StatefulWidget {
  const clientpage({super.key});

  @override
  State<clientpage> createState() => _clientpageState();
}

class _clientpageState extends State<clientpage> {
  String? _activeCommandeId;
  String  _activeClientNom   = '';
  double  _activeVolumeLivre = 0.0;
  String  _activeAdresse     = '';
  bool    _loadingCommande   = true;

  @override
  void initState() {
    super.initState();
    _loadActiveCommande();
  }

  Future<void> _loadActiveCommande() async {
    setState(() => _loadingCommande = true);
    try {
      final commandes = await ApiService.getMyCommandes();
      final active = commandes.firstWhere(
            (c) =>
        c['status'] != 'livree' &&
            c['status'] != 'annulee' &&
            c['status'] != 'refusee',
        orElse: () => {},
      );
      if (active.isNotEmpty && mounted) {
        final clientInfo = await ApiService.getClientInfo();
        final clientNom =
        '${clientInfo['prenom'] ?? ''} ${clientInfo['nom'] ?? ''}'.trim();

        setState(() {
          _activeCommandeId  = (active['_id'] ?? active['id']).toString();
          _activeClientNom   = clientNom.isNotEmpty ? clientNom : 'Client';
          _activeVolumeLivre = (active['capacite'] as num?)?.toDouble() ?? 0.0;
          _activeAdresse     = active['adresse']?.toString() ??
              '${active['lat'] ?? ''}, ${active['lon'] ?? ''}';
        });
      }
    } catch (e) {
      debugPrint('Error loading active commande: $e');
    } finally {
      if (mounted) setState(() => _loadingCommande = false);
    }
  }

  Widget roleCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.blue,
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0C2A34),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Bienvenue 👋',
              style: TextStyle(
                color: Color(0xFF4ECDC4),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'client profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: const [
          Icon(Icons.water_drop, color: Color(0xFF4ECDC4), size: 28),
          SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: Color(0xFF1a5a6a),
            radius: 20,
            child: Icon(Icons.person, color: Colors.white, size: 22),
          ),
          SizedBox(width: 16),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top:   screenHeight * 0.03,
          left:  screenWidth  * 0.04,
          right: screenWidth  * 0.04,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ---- Profile Card ----
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth  * 0.04,
                vertical:   screenHeight * 0.015,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3C49),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFF0C2A34),
                    child: Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'rezik rabah',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'client depuis 2023',
                        style: TextStyle(
                          color: Colors.lightBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: screenHeight * 0.015),

            // ---- Role Cards ----
            Row(
              children: [
                roleCard(
                  icon:  Icons.local_shipping_sharp,
                  title: "  12\n commande",
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => clientpage()));
                  },
                ),
                roleCard(
                  icon:  Icons.water_drop_rounded,
                  title: "1100L",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => commandes(
                          clientId:
                          int.tryParse(ApiService.userId ?? '0') ?? 0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.03),

            // ---- Last Orders Card ----
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3C49),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dernières commandes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => historique()));
                        },
                        child: const Text(
                          'voir tout ->',
                          style: TextStyle(fontSize: 13, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  _orderRow('1 citerne x500L', '25 Décembre 2024',
                      'Livrée ✓', Colors.green, screenWidth),
                  SizedBox(height: screenHeight * 0.01),
                  _orderRow('1 citerne x400L', '02 Janvier 2025',
                      'Livrée ✓', Colors.green, screenWidth),
                  SizedBox(height: screenHeight * 0.01),
                  _orderRow('1 citerne x200L', '25 Janvier 2026',
                      'en cours...', Colors.orangeAccent, screenWidth),
                ],
              ),
            ),

            SizedBox(height: screenHeight * 0.02),

            // ---- Track commande button ----
            Container(
              width: double.infinity,
              height: screenHeight * 0.07,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0B3C49),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _loadingCommande
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : TextButton(
                onPressed: _activeCommandeId == null
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientTrackingPage(
                        commandeId:  _activeCommandeId!,
                        clientId:    ApiService.userId ?? '0',
                        clientNom:   _activeClientNom,
                        volumeLivre: _activeVolumeLivre,
                        adresse:     _activeAdresse,
                      ),
                    ),
                  );
                },
                child: Text(
                  _activeCommandeId == null
                      ? 'Aucune commande active'
                      : 'Suivre ma commande',
                  style: TextStyle(
                    color: _activeCommandeId == null
                        ? Colors.white38
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.02),
          ],
        ),
      ),

      // ---- FAB ----
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: const Color(0xFF0B3C49),
        shape: const CircleBorder(),
        child: const Icon(CupertinoIcons.home, color: Colors.white, size: 20),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => clientpage()));
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ---- Bottom Nav ----
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8,
        height: screenHeight * 0.1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(CupertinoIcons.map, 'suivi', () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => suivi()));
            }),
            const SizedBox(width: 35),
            _navItem(CupertinoIcons.cube_box_fill, 'commandes', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => commandes(
                    clientId: int.tryParse(ApiService.userId ?? '0') ?? 0,
                  ),
                ),
              );
            }),
            const SizedBox(width: 25),
            _navItem(CupertinoIcons.clock, 'historique', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => historique()));
            }),
            const SizedBox(width: 22),
            _navItem(CupertinoIcons.profile_circled, 'profile', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => profile()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(String title, String date, String status,
      Color statusColor, double screenWidth) {
    return Row(
      children: [
        const Icon(Icons.local_shipping_sharp,
            color: Color(0xFF4ECDC4), size: 28),
        SizedBox(width: screenWidth * 0.02),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: '\n$date',
                  style: const TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 50, width: 1, color: Colors.white24),
        SizedBox(width: screenWidth * 0.03),
        Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 20, color: const Color(0xFF0B3C49)),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 8, color: Color(0xFF0B3C49))),
      ],
    );
  }
}