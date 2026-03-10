import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:test2/client/clientpage.dart';
import 'package:test2/pages/fournisseurinfos.dart';
import '../services/api_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String? userId; // null when coming from login (role already chosen)

  const RoleSelectionScreen({super.key, this.userId});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {

  bool _isLoading = false;

  // ── Called when user picks a role ──
  Future<void> _selectRole(String role) async {
    // If userId is null → user came from login, skip chooseRole and go directly
    if (widget.userId == null) {
      _navigate(role);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.chooseRole(
      userId: widget.userId!,
      role: role,
    );

    setState(() => _isLoading = false);

    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result['msg'] == 'role already chosen') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Role already set. Please login.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ Role saved — navigate to correct page
    _navigate(role);
  }

  void _navigate(String role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
        role == 'client' ? clientpage() : fournisseurinfos(),
      ),
    );
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String role,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : () => _selectRole(role),
        child: Container(
          height: 160,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.blue,
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0B3C49),
                  fontSize: 18,
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
    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        title: const Text(
          "choose your role",
          style: TextStyle(color: Color(0xFFEAFBFF)),
        ),
        backgroundColor: const Color(0xFF0B3C49),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.water_drop, size: 30, color: Color(0xFF1E88E5)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundImage: CachedNetworkImageProvider(
                'https://img.freepik.com/premium-vector/water-vector-logo-design-white-background_1277164-15228.jpg',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Vous êtes ?",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3C49),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                _roleCard(
                  icon: Icons.person,
                  title: "Client",
                  role: "client",
                ),
                _roleCard(
                  icon: Icons.local_shipping,
                  title: "Fournisseur",
                  role: "fournisseur",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}