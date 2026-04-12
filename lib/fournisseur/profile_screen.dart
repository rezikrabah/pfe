// ================================================================
// FICHIER : profile_screen.dart
// ================================================================

import 'package:flutter/material.dart';
import 'package:test2/pages/Loginpage.dart';
import 'package:test2/main.dart';

import '../gerant/Info.dart';
import '../services/api_service.dart';
import 'ChauffeurScreen.dart';
import 'Join_gerant_screen.dart';

// ================================================================
// 1. ÉCRAN PRINCIPAL DU PROFIL
// ================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // ── State ──────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;

  // Real data from DB
  String _name       = '';
  String _phone      = '';
  String _email      = '';
  double _rating     = 0.0;
  int    _totalDeliveries = 0;
  int    _trucks     = 0;
  int    _totalCapacity = 0;
  String _memberSince = '';
  String _role       = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Load from DB ───────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      // Use getGerantInfo() → GET /api/auth/me  (works for all roles)
      final data = await ApiService.getGerantInfo();

      if (data['error'] != null) {
        setState(() { _error = data['error']; _isLoading = false; });
        return;
      }

      // The response shape from /api/auth/me:
      // { nom, prenom, email, telephone, role, createdAt,
      //   fournisseurInfo: { quantiteEau, wilayas, ... } }
      final String nom    = data['nom']    ?? '';
      final String prenom = data['prenom'] ?? '';

      // For fournisseurs, also fetch /api/fournisseurs/me for richer data
      Map<String, dynamic> fournisseurData = {};
      if (ApiService.userRole == 'fournisseur' ||
          ApiService.userRole == 'gerant') {
        fournisseurData = await ApiService.getMyInfo();
      }

      // Parse member-since date
      String memberSince = '';
      if (data['createdAt'] != null) {
        try {
          final dt = DateTime.parse(data['createdAt'].toString());
          const months = [
            '', 'Janvier','Février','Mars','Avril','Mai','Juin',
            'Juillet','Août','Septembre','Octobre','Novembre','Décembre'
          ];
          memberSince = '${months[dt.month]} ${dt.year}';
        } catch (_) {}
      }

      setState(() {
        _name   = '$nom $prenom'.trim();
        _phone  = data['telephone'] ?? '';
        _email  = data['email']     ?? '';
        _role   = data['role']      ?? ApiService.userRole ?? '';
        _memberSince = memberSince;

        // Fournisseur-specific fields
        if (fournisseurData['error'] == null) {
          _rating    = (fournisseurData['rating']   as num?)?.toDouble() ?? 0.0;
          _totalDeliveries = (fournisseurData['totalLivraisons'] as num?)?.toInt() ?? 0;
          // capaciteCamion comes as a number (litres)
          _totalCapacity   = (fournisseurData['quantiteEau'] as num?)?.toInt() ?? 0;
          // chauffeurs list length if gerant
          final chauffeurs = fournisseurData['chauffeurs'];
          _trucks = (chauffeurs is List) ? chauffeurs.length : 0;
        }

        _isLoading = false;
      });

    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Logout ─────────────────────────────────────────────────────
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Se déconnecter',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              // Clear stored session
              ApiService.token    = null;
              ApiService.userId   = null;
              ApiService.userRole = null;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => Loginpage()),
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

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : _error != null
          ? _buildErrorState()
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildStatsSection(),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text('Impossible de charger le profil',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      child: Column(
        children: [
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.person,
                    size: 50, color: Color(0xFF1E3A8A)),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt,
                      size: 20, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_name.isNotEmpty ? _name : 'Utilisateur',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          // Role badge
          if (_role.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _role.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2),
              ),
            ),
          if (_rating > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text('${_rating.toStringAsFixed(1)} / 5.0',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          // Member since
          if (_memberSince.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Membre depuis $_memberSince',
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques Globales',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    icon: Icons.local_shipping,
                    label: 'Camions',
                    value: '$_trucks',
                    color: const Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    icon: Icons.water_drop,
                    label: 'Capacité totale',
                    value: '$_totalCapacity L',
                    color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    icon: Icons.delivery_dining,
                    label: 'Livraisons',
                    value: '$_totalDeliveries',
                    color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    icon: Icons.star,
                    label: 'Note',
                    value: _rating > 0
                        ? '${_rating.toStringAsFixed(1)}/5'
                        : 'N/A',
                    color: Colors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      {required IconData icon,
        required String label,
        required String value,
        required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Paramètres',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
          ),

          _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Informations personnelles',
              subtitle: _email,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PersonalInfoScreen(
                        name: _name,
                        phone: _phone,
                        email: _email,
                      )))),
          _buildDivider(),

          _buildMenuItem(
              icon: Icons.local_shipping_outlined,
              title: 'Mes camions',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          _buildDivider(),

          _buildMenuItem(
              icon: Icons.payment_outlined,
              title: 'Paiements & Facturation',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          _buildDivider(),

          _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const ProfileScreen()))),
          _buildDivider(),

          _buildMenuItem(
              icon: Icons.language_outlined,
              title: 'Langue',
              subtitle: 'Français',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          _buildDivider(),

          _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Aide & Support',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()))),
          _buildDivider(),

          ValueListenableBuilder<bool>(
            valueListenable: themeNotifier,
            builder: (context, isDark, child) {
              return _buildMenuItem(
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: isDark ? 'Mode sombre' : 'Mode clair',
                subtitle: isDark
                    ? 'Appuyer pour mode clair'
                    : 'Appuyer pour mode sombre',
                onTap: () {
                  themeNotifier.value = !themeNotifier.value;
                },
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JoinGerantScreen())),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Rejoindre un gérant'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      {required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface)),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1,
        indent: 76,
        endIndent: 20,
        color: Theme.of(context).dividerColor);
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter',
              style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

// ================================================================
// 2. ÉCRAN : INFORMATIONS PERSONNELLES  (now accepts real data)
// ================================================================
class PersonalInfoScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String email;

  const PersonalInfoScreen({
    Key? key,
    this.name  = '',
    this.phone = '',
    this.email = '',
  }) : super(key: key);

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {

  bool _isEditing = false;
  bool _isSaving  = false;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _addressController        = TextEditingController(text: '');
  final _registrationController   = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _nameController  = TextEditingController(text: widget.name);
    _phoneController = TextEditingController(text: widget.phone);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    // TODO: wire to a real update endpoint when available
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() { _isEditing = false; _isSaving = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Informations mises à jour avec succès'),
          backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Informations personnelles'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)),
          )
              : TextButton(
            onPressed: () {
              if (_isEditing) _saveChanges();
              else setState(() => _isEditing = true);
            },
            child: Text(_isEditing ? 'Enregistrer' : 'Modifier',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Stack(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: const Icon(Icons.person,
                            size: 50, color: Color(0xFF1E3A8A)),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_nameController.text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations de base',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 20),
                  _buildField(
                      icon: Icons.person_outline,
                      label: 'Nom complet / Entreprise',
                      controller: _nameController,
                      enabled: _isEditing),
                  const SizedBox(height: 16),
                  _buildField(
                      icon: Icons.phone_outlined,
                      label: 'Téléphone',
                      controller: _phoneController,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildField(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      controller: _emailController,
                      enabled: _isEditing,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildField(
                      icon: Icons.location_on_outlined,
                      label: 'Adresse',
                      controller: _addressController,
                      enabled: _isEditing),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Documents légaux',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 20),
                  _buildField(
                      icon: Icons.business_outlined,
                      label: 'Numéro de registre commercial',
                      controller: _registrationController,
                      enabled: _isEditing),
                  const SizedBox(height: 16),
                  _buildDocumentButton(
                      icon: Icons.upload_file,
                      label: 'Registre commercial',
                      status: 'Vérifié',
                      statusColor: Colors.green),
                  const SizedBox(height: 12),
                  _buildDocumentButton(
                      icon: Icons.upload_file,
                      label: 'Carte nationale',
                      status: 'Vérifié',
                      statusColor: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  Widget _buildField(
      {required IconData icon,
        required String label,
        required TextEditingController controller,
        bool enabled = false,
        TextInputType? keyboardType}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A)),
        filled: true,
        fillColor: enabled
            ? (isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.2)
            : Colors.blue[50])
            : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[50]),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey[200]!,
                width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFF1E3A8A), width: 2)),
      ),
    );
  }

  Widget _buildDocumentButton(
      {required IconData icon,
        required String label,
        required String status,
        required Color statusColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface))),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text(status,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Keep the rest of your screens unchanged below this line:
// MyCamionsScreen, AddTruckBottomSheet, PaymentsScreen,
// NotificationsSettingsScreen, LanguageScreen, HelpSupportScreen
// ================================================================