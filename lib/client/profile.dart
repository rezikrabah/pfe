import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test2/client/historique.dart';
import 'package:test2/client/suivi.dart';
import 'package:test2/pages/Loginpage.dart';

import '../services/api_service.dart';
import 'clientpage.dart';
import 'commandes.dart';

void main() => runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: profile(),
    )
);

class profile extends StatefulWidget {
  const profile({super.key});

  @override
  State<profile> createState() => _profileState();
}

class _profileState extends State<profile> {
  // --- Color Palette ---
  static const Color kPrimaryDark   = Color(0xFF0B3C49);
  static const Color kPrimaryMid    = Color(0xFF1F6F7F);
  static const Color kAccent        = Color(0xFF1E88E5);
  static const Color kAccentLight   = Color(0xFF6FB6C3);
  static const Color kBackground    = Color(0xFFF0F4FF);
  static const Color kCardBg        = Color(0xFFFFFFFF);
  static const Color kTextPrimary   = Color(0xFF0B3C49);
  static const Color kTextSecondary = Color(0xFF607D8B);
  static const Color kLogout        = Color(0xFFE53935);


  final String userName     = 'rezik rabah';
  final String userEmail    = 'rezikrabah1@gmail.com';
  final String userPhone    = '+213 555 123 456';
  final String memberSince  = 'Membre depuis  2023';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      resizeToAvoidBottomInset: true,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: kPrimaryDark,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 26, color: Colors.white),
            onPressed: () {
              // TODO: navigate to settings
            },
          ),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [

            // ── Header / Avatar banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: const BoxDecoration(
                color: kPrimaryDark,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: kAccentLight,
                        child: const Icon(Icons.person, color: Colors.white, size: 48),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Name
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Member since badge
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccentLight.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      memberSince,
                      style: const TextStyle(
                        color: kAccentLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick stats row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatCard('12', 'Commandes', Icons.indeterminate_check_box_rounded),
                  const SizedBox(width: 12),
                  _buildStatCard('9', 'Livrées', Icons.check_circle_outline),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Section label ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PARAMÈTRES',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Settings cards ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryDark.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.person_outline,
                      iconBg: const Color(0xFFE3F2FD),
                      iconColor: kAccent,
                      title: 'Informations personnelles',
                      subtitle: 'Nom, email, téléphone',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => profile()),
                        );
                      },
                      isFirst: true,
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.credit_card_outlined,
                      iconBg: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF43A047),
                      title: 'Paiements & Facturation',
                      subtitle: 'Méthodes de paiement, factures',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => profile()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.notifications_none_outlined,
                      iconBg: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFFF8F00),
                      title: 'Notifications',
                      subtitle: 'Alertes, rappels, promotions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => profile()),
                        );
                      },
                      trailing: _buildToggle(),
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.language_outlined,
                      iconBg: const Color(0xFFF3E5F5),
                      iconColor: const Color(0xFF8E24AA),
                      title: 'Langue',
                      subtitle: 'Français',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => profile()),
                        );
                      },
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Support section ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SUPPORT',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryDark.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.help_outline,
                      iconBg: const Color(0xFFE3F2FD),
                      iconColor: kAccent,
                      title: 'Aide & Support',
                      subtitle: 'FAQ, contacter le support',
                      onTap: () {},
                      isFirst: true,
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.shield_outlined,
                      iconBg: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF43A047),
                      title: 'Confidentialité',
                      subtitle: 'Politique de confidentialité',
                      onTap: () {},
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ── Logout button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Loginpage()),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                  label: const Text(
                    'SE DÉCONNECTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLogout,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: kLogout.withOpacity(0.4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),

      // ── Bottom Navigation ────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryDark,
        shape: const CircleBorder(),
        mini: true,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => clientpage()),
          );
        },
        child: const Icon(CupertinoIcons.home, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 12,
        notchMargin: 8,
        height: 72,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(CupertinoIcons.map, 'Suivi', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => suivi()));
            }),
            _buildNavItem(CupertinoIcons.cube_box_fill, 'Commandes', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => commandes(
                    clientId: int.tryParse(ApiService.userId ?? '0') ?? 0,
                  ),
                ),
              );
            }),
            const SizedBox(width: 40), // FAB gap
            _buildNavItem(CupertinoIcons.clock, 'Historique', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => historique()));
            }),
            _buildNavItem(CupertinoIcons.profile_circled, 'Profil', () {}, isActive: true),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ───────────────────────────────────────────────────────────

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimaryDark.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kAccent, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Coloured icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing widget or chevron
              trailing ??
                  const Icon(
                    CupertinoIcons.chevron_right,
                    color: kTextSecondary,
                    size: 16,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  Widget _buildToggle() {
    return Switch(
      value: true,
      onChanged: (v) {},
      activeColor: kAccent,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildNavItem(
      IconData icon,
      String label,
      VoidCallback onTap, {
        bool isActive = false,
      }) {
    final color = isActive ? kAccent : kPrimaryDark.withOpacity(0.55);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}