import 'package:flutter/material.dart';
import 'package:test2/services/api_service.dart';
// TODO: import your login page, e.g:
// import 'package:test2/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool                _loading  = true;
  Map<String, dynamic> _data    = {};
  List<dynamic>        _chauffeurs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load chauffeurs to compute truck count + total capacity
    final chauffeurs = await ApiService.getMyChauffeurs();
    final commandes  = await ApiService.getAllCommandes(status: 'livrée');

    final totalCapacity = chauffeurs.fold<double>(
        0, (sum, c) => sum + ((c['capaciteCamion'] as num?)?.toDouble() ?? 0));

    setState(() {
      _chauffeurs = chauffeurs;
      _data = {
        'nom':             ApiService.userId ?? 'Utilisateur',
        'trucks':          chauffeurs.length,
        'totalCapacity':   totalCapacity.toStringAsFixed(0),
        'totalDeliveries': commandes.length,
      };
      _loading = false;
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              // Clear session
              ApiService.token    = null;
              ApiService.userId   = null;
              ApiService.userRole = null;
              Navigator.pop(context);
              // Navigate back to login and clear all routes
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login', // ← make sure this route exists in your MaterialApp
                    (route) => false,
              );
            },
            child: const Text('Se déconnecter',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildStatsSection(),
            const SizedBox(height: 16),
            _buildChauffeursList(),
            const SizedBox(height: 16),
            _buildSettingsMenu(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Profile header ────────────────────────────────────────

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        const SizedBox(height: 24),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.store, size: 50, color: Color(0xFF1E3A8A)),
        ),
        const SizedBox(height: 16),
        Text(
          // Show real user ID until you load full profile
          'Fournisseur #${ApiService.userId ?? '—'}',
          style: const TextStyle(color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            ApiService.userRole?.toUpperCase() ?? 'FOURNISSEUR',
            style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Stats ─────────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Statistiques', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildStatCard(
            icon: Icons.local_shipping,
            label: 'Chauffeurs',
            value: '${_data['trucks'] ?? 0}',
            color: const Color(0xFF1E3A8A),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            icon: Icons.water_drop,
            label: 'Capacité totale',
            value: '${_data['totalCapacity'] ?? 0} L',
            color: Colors.blue,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildStatCard(
            icon: Icons.delivery_dining,
            label: 'Livrées',
            value: '${_data['totalDeliveries'] ?? 0}',
            color: Colors.green,
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            icon: Icons.pending_actions,
            label: 'En attente',
            value: '—',   // hook up pending count if needed
            color: Colors.orange,
          )),
        ]),
      ]),
    );
  }

  Widget _buildStatCard({required IconData icon, required String label,
    required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ── Chauffeurs list ───────────────────────────────────────

  Widget _buildChauffeursList() {
    if (_chauffeurs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mes Chauffeurs', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._chauffeurs.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF1E3A8A),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['nom'] ?? '—', style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('${c['telephone'] ?? '—'}  •  '
                      '${c['capaciteCamion'] ?? 0} L',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ])),
          ]),
        )),
      ]),
    );
  }

  // ── Settings menu ─────────────────────────────────────────

  Widget _buildSettingsMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Paramètres', style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold)),
        ),
        _buildMenuItem(icon: Icons.person_outline,
            title: 'Informations personnelles', onTap: () {}),
        _buildDivider(),
        _buildMenuItem(icon: Icons.local_shipping_outlined,
            title: 'Mes chauffeurs', onTap: () {}),
        _buildDivider(),
        _buildMenuItem(icon: Icons.notifications_outlined,
            title: 'Notifications', onTap: () {}),
        _buildDivider(),
        _buildMenuItem(icon: Icons.help_outline,
            title: 'Aide & Support', onTap: () {}),
      ]),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title,
    String? subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 14,
                      color: Colors.grey[600])),
                ],
              ])),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, indent: 76,
      endIndent: 20, color: Colors.grey[200]);

  // ── Logout button ─────────────────────────────────────────

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}