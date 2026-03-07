import 'package:flutter/material.dart';
// 1. Remplacement des imports Google Maps par Flutter Map
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'orders_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({Key? key}) : super(key: key);

  @override
  State<ProviderHomeScreen> createState() => ProviderHomeScreenState();
}

class ProviderHomeScreenState extends State<ProviderHomeScreen> {
  // 2. Utilisation du MapController de flutter_map
  final MapController _mapController = MapController();
  bool isOnline = false;
  int currentIndex = 0;

  final LatLng _currentPosition = const LatLng(36.7538, 3.0588);
  final int capacityLiters = 5400;

  // 3. Adaptation de la liste des marqueurs pour OSM
  List<Marker> markers = [];

  @override
  void initState() {
    super.initState();
    _updateTruckMarker();
  }

  void _updateTruckMarker() {
    setState(() {
      markers = [
        Marker(
          point: _currentPosition,
          width: 80,
          height: 80,
          child: const Icon(
            Icons.location_on,
            color: Colors.blue, // Couleur "Azure" comme précédemment
            size: 45,
          ),
        ),
      ];
    });
  }

  void _toggleOnlineStatus() {
    setState(() {
      isOnline = !isOnline;
    });

    if (isOnline) {
      _showSuccess('Vous êtes maintenant EN LIGNE');
    } else {
      _showSuccess('Vous êtes maintenant HORS LIGNE');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMapScreen() {
    return Stack(
      children: [
        // 4. Remplacement de GoogleMap par FlutterMap
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.water_delivery_app',
            ),
            MarkerLayer(
              markers: markers,
            ),
          ],
        ),

        // Header avec menu et capacité (Inchangé)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Placeholder pour le menu
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping, color: Color(0xFF1E3A8A), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            '$capacityLiters L',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bouton de recentrage (Adapté pour MapController)
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 100,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              _mapController.move(_currentPosition, 13.0);
            },
            child: const Icon(Icons.my_location, color: Color(0xFF1E3A8A)),
          ),
        ),

        // Statut et bouton GO (Inchangé)
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? 'VOUS ÊTES EN LIGNE' : 'VOUS ÊTES HORS LIGNE',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.green : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOnline ? 'Vous recevez des commandes.' : 'Vous ne recevez pas de commandes.',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleOnlineStatus,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Colors.red : const Color(0xFF1E3A8A),
                        boxShadow: [
                          BoxShadow(
                            color: (isOnline ? Colors.red : const Color(0xFF1E3A8A)).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isOnline ? 'STOP' : 'GO',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          _buildMapScreen(),
          const OrdersScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E3A8A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Commandes'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}