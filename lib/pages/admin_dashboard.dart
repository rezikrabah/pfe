import 'package:flutter/material.dart';

import 'Loginpage.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaveauAdmin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==================== SHARED SIGNALEMENT DIALOG ====================
const List<String> kRaisonsSignalement = [
  'Comportement inapproprié',
  'Retard répété',
  'Fraude / impayé',
  'Contenu abusif',
  'Non-respect des règles',
  'Autre',
];

void showSignalementDialog(BuildContext context, {String? defaultTarget}) {
  final TextEditingController messageCtrl = TextEditingController();
  final TextEditingController targetCtrl = TextEditingController(text: defaultTarget ?? '');
  String? selectedRaison;
  String targetType = 'Client';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  const Text('Envoyer un signalement',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Envoyer à :', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: ['Client', 'Chauffeur'].map((t) {
                  final selected = targetType == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      selectedColor: const Color(0xFF1E3A8A),
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
                      onSelected: (_) => setModalState(() => targetType = t),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du $targetType',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Raison (choix rapide) :', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: kRaisonsSignalement.map((r) {
                  final selected = selectedRaison == r;
                  return ChoiceChip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: Colors.red.shade100,
                    labelStyle: TextStyle(color: selected ? Colors.red.shade800 : Colors.black),
                    onSelected: (_) {
                      setModalState(() {
                        selectedRaison = selected ? null : r;
                        if (!selected) messageCtrl.text = r;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message personnalisé (optionnel)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Signalement envoyé à ${targetCtrl.text.isNotEmpty ? targetCtrl.text : targetType}'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer le signalement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ==================== ÉCRAN D'ACCUEIL ====================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<Map<String, dynamic>> _sections = [
    {'title': 'Comptes utilisateurs', 'icon': Icons.people_outline, 'color': Colors.blue, 'screen': 'users'},
    {'title': 'Chauffeurs', 'icon': Icons.local_shipping_outlined, 'color': Colors.green, 'screen': 'drivers'},
    {'title': 'Commandes', 'icon': Icons.receipt_long_outlined, 'color': Colors.orange, 'screen': 'orders'},
    {'title': 'Avertissements', 'icon': Icons.notifications_outlined, 'color': Colors.red, 'screen': 'warnings'},
    {'title': 'Réclamations', 'icon': Icons.message_outlined, 'color': Colors.purple, 'screen': 'claims'},
    {'title': 'Notes & avis', 'icon': Icons.star_outline, 'color': Colors.amber, 'screen': 'reviews'},
    {'title': 'Journal d\'activité', 'icon': Icons.history_outlined, 'color': Colors.teal, 'screen': 'logs'},
    {'title': 'Paramètres', 'icon': Icons.settings_outlined, 'color': Colors.grey, 'screen': 'settings'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdminWaveau - Tableau de bord'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bienvenue,', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
            const Text('Administrateur', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            const Text('Choisissez une section pour continuer',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.2,
                ),
                itemCount: _sections.length,
                itemBuilder: (context, index) {
                  final s = _sections[index];
                  return _buildCard(context, s['title'], s['icon'], s['color'], s['screen']);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, Color color, String screen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _buildScreen(screen, title))),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(String screen, String title) {
    switch (screen) {
      case 'users': return const UsersScreen();
      case 'drivers': return const DriversScreen();
      case 'orders': return const OrdersScreen();
      case 'warnings': return const WarningsScreen();
      case 'claims': return const ClaimsScreen();
      case 'reviews': return const ReviewsScreen();
      case 'logs': return const LogsScreen();
      case 'settings': return const SettingsScreen();
      default: return SectionScreen(title: title);
    }
  }
}

// ==================== APPBAR COMMUN ====================
AppBar buildAppBar(String title) => AppBar(
  title: Text(title),
  backgroundColor: const Color(0xFF1E3A8A),
  foregroundColor: Colors.white,
  leading: Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.arrow_back_ios_new),
      onPressed: () => Navigator.pop(context),
    ),
  ),
);

// ==================== COMPTES UTILISATEURS ====================
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final List<Map<String, dynamic>> _users = [
    {'name': 'Ahmed Benali', 'email': 'ahmed.benali@email.com', 'phone': '0555 123 456', 'address': '12 Rue des Mimosas, Alger', 'status': 'Actif', 'orders': 12, 'balance': 1500},
    {'name': 'Sara Khalil', 'email': 'sara.khalil@email.com', 'phone': '0661 789 012', 'address': '7 Cité El Badr, Oran', 'status': 'Actif', 'orders': 7, 'balance': 800},
    {'name': 'Mohamed Ait', 'email': 'med.ait@email.com', 'phone': '0770 345 678', 'address': '3 Lotissement Saada, Constantine', 'status': 'Suspendu', 'orders': 3, 'balance': 0},
    {'name': 'Fatima Zohra', 'email': 'f.zohra@email.com', 'phone': '0553 901 234', 'address': '22 Boulevard Zighoud, Annaba', 'status': 'Actif', 'orders': 21, 'balance': 3200},
    {'name': 'Karim Djamel', 'email': 'karim.dj@email.com', 'phone': '0660 567 890', 'address': '5 Rue Didouche, Blida', 'status': 'Inactif', 'orders': 0, 'balance': 0},
  ];
  String _filter = 'Tous';

  Color _statusColor(String s) =>
      s == 'Actif' ? Colors.green : s == 'Suspendu' ? Colors.red : Colors.grey;

  void _showProfile(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 28, backgroundColor: Colors.blue.shade100,
                    child: Text(user['name'][0], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _statusColor(user['status']).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(user['status'], style: TextStyle(color: _statusColor(user['status']), fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ])),
              ]),
              const Divider(height: 28),
              _infoRow(Icons.email_outlined, user['email']),
              _infoRow(Icons.phone_outlined, user['phone']),
              _infoRow(Icons.location_on_outlined, user['address']),
              _infoRow(Icons.receipt_long_outlined, '${user['orders']} commandes'),
              _infoRow(Icons.account_balance_wallet_outlined, 'Solde : ${user['balance']} DA'),
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _actionBtn('Réinitialiser MDP', Icons.lock_reset, Colors.blue, () => Navigator.pop(ctx)),
                _actionBtn(
                  user['status'] == 'Suspendu' ? 'Débloquer' : 'Suspendre',
                  user['status'] == 'Suspendu' ? Icons.lock_open : Icons.block,
                  user['status'] == 'Suspendu' ? Colors.green : Colors.orange,
                      () {
                    setState(() => user['status'] = user['status'] == 'Suspendu' ? 'Actif' : 'Suspendu');
                    Navigator.pop(ctx);
                  },
                ),
                _actionBtn('Signalement', Icons.flag_outlined, Colors.red,
                        () { Navigator.pop(ctx); showSignalementDialog(context, defaultTarget: user['name']); }),
                _actionBtn('Supprimer', Icons.delete_outline, Colors.red.shade900, () {
                  Navigator.pop(ctx);
                  _confirmDelete(user);
                }),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
    ]),
  );

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: color.withOpacity(0.4))),
      );

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le compte de ${user['name']} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _users.remove(user));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Compte de ${user['name']} supprimé'), backgroundColor: Colors.red));
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'Tous' ? _users : _users.where((u) => u['status'] == _filter).toList();
    return Scaffold(
      appBar: buildAppBar('Comptes utilisateurs'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'Actif', 'Suspendu', 'Inactif'].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: const Color(0xFF1E3A8A).withOpacity(0.15),
                      checkmarkColor: const Color(0xFF1E3A8A),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final user = filtered[i];
                final color = _statusColor(user['status']);
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(user['name'][0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(user['email']),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(user['status'], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 4),
                        Text('${user['orders']} commandes', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    onTap: () => _showProfile(user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CHAUFFEURS ====================
class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});
  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final List<Map<String, dynamic>> _drivers = [
    {'name': 'Youcef Mansouri', 'phone': '0555 123 456', 'zone': 'Alger Centre', 'deliveries': 145, 'rating': 4.8, 'monthly': 32, 'status': 'Actif', 'available': true},
    {'name': 'Rachid Bouzid', 'phone': '0661 789 012', 'zone': 'Bab Ezzouar', 'deliveries': 98, 'rating': 4.2, 'monthly': 18, 'status': 'Actif', 'available': false},
    {'name': 'Hamza Tizi', 'phone': '0770 345 678', 'zone': 'Kouba', 'deliveries': 212, 'rating': 4.9, 'monthly': 47, 'status': 'Actif', 'available': true},
    {'name': 'Nassim Oubira', 'phone': '0553 901 234', 'zone': 'Hussein Dey', 'deliveries': 67, 'rating': 3.7, 'monthly': 11, 'status': 'Suspendu', 'available': false},
    {'name': 'Bilal Meziane', 'phone': '0660 567 890', 'zone': 'El Harrach', 'deliveries': 34, 'rating': 4.5, 'monthly': 8, 'status': 'Inactif', 'available': false},
  ];
  String _filter = 'Tous';

  Color _statusColor(String s) =>
      s == 'Actif' ? Colors.green : s == 'Suspendu' ? Colors.red : Colors.grey;

  final List<String> _zones = ['Alger Centre', 'Bab Ezzouar', 'Kouba', 'Hussein Dey', 'El Harrach', 'Birkhadem'];

  void _showDriverDetail(Map<String, dynamic> d) {
    String selectedZone = d['zone'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Stack(children: [
                    CircleAvatar(radius: 28, backgroundColor: Colors.green.shade100,
                        child: Icon(Icons.local_shipping, color: Colors.green.shade700, size: 28)),
                    Positioned(right: 0, bottom: 0,
                        child: Container(width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: d['available'] ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ))),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['name'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(d['phone'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor(d['status']).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(d['status'], style: TextStyle(color: _statusColor(d['status']), fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ])),
                ]),
                const Divider(height: 28),
                Row(children: [
                  _statBox('Total livr.', '${d['deliveries']}', Colors.blue),
                  const SizedBox(width: 10),
                  _statBox('Ce mois', '${d['monthly']}', Colors.teal),
                  const SizedBox(width: 10),
                  _statBox('Note moy.', '${d['rating']}★', Colors.amber),
                ]),
                const SizedBox(height: 16),
                const Text('Zone d\'affectation :', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedZone,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.map_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                  onChanged: (v) => setModal(() => selectedZone = v!),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        d['zone'] = selectedZone;
                        d['status'] = d['status'] == 'Suspendu' ? 'Actif' : 'Suspendu';
                        d['available'] = d['status'] == 'Actif';
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${d['name']} : statut mis à jour')));
                    },
                    icon: Icon(d['status'] == 'Suspendu' ? Icons.lock_open : Icons.block, size: 16,
                        color: d['status'] == 'Suspendu' ? Colors.green : Colors.orange),
                    label: Text(d['status'] == 'Suspendu' ? 'Réactiver' : 'Suspendre',
                        style: TextStyle(color: d['status'] == 'Suspendu' ? Colors.green : Colors.orange, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.orange.withOpacity(0.4))),
                  ),
                  OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); showSignalementDialog(context, defaultTarget: d['name']); },
                    icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.red),
                    label: const Text('Signalement', style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.withOpacity(0.4))),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => d['zone'] = selectedZone);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zone mise à jour')));
                    },
                    icon: const Icon(Icons.save_outlined, size: 16, color: Color(0xFF1E3A8A)),
                    label: const Text('Enregistrer zone', style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFF1E3A8A).withOpacity(0.4))),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'Tous' ? _drivers : _drivers.where((d) => d['status'] == _filter).toList();
    return Scaffold(
      appBar: buildAppBar('Chauffeurs'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nouveau chauffeur'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'Actif', 'Suspendu', 'Inactif'].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: Colors.green.withOpacity(0.15),
                      checkmarkColor: Colors.green,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = filtered[i];
                final statusColor = _statusColor(d['status']);
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: Stack(children: [
                      CircleAvatar(radius: 24, backgroundColor: Colors.green.shade100,
                          child: Icon(Icons.local_shipping, color: Colors.green.shade700)),
                      Positioned(right: 0, bottom: 0,
                          child: Container(width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: d['available'] ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ))),
                    ]),
                    title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['phone'], style: const TextStyle(fontSize: 12)),
                      Text('Zone : ${d['zone']}', style: const TextStyle(fontSize: 12)),
                    ]),
                    trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(d['status'], style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 4),
                      Text('${d['rating']}★', style: const TextStyle(fontSize: 13, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ]),
                    onTap: () => _showDriverDetail(d),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== COMMANDES ====================
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final List<Map<String, dynamic>> _orders = [
    {'id': '#CMD-0042', 'client': 'Ahmed Benali', 'address': '12 Rue des Mimosas, Alger', 'qty': '3 bouteilles 19L', 'driver': 'Hamza Tizi', 'status': 'En cours', 'date': '15 avr. 2026', 'time': '10:23'},
    {'id': '#CMD-0041', 'client': 'Fatima Zohra', 'address': '22 Boulevard Zighoud, Annaba', 'qty': '1 bonbonne 10L', 'driver': 'Youcef Mansouri', 'status': 'Livré', 'date': '14 avr. 2026', 'time': '15:10'},
    {'id': '#CMD-0040', 'client': 'Sara Khalil', 'address': '7 Cité El Badr, Oran', 'qty': '5 bouteilles 19L', 'driver': 'Nassim Oubira', 'status': 'Livré', 'date': '13 avr. 2026', 'time': '11:45'},
    {'id': '#CMD-0039', 'client': 'Karim Djamel', 'address': '5 Rue Didouche, Blida', 'qty': '2 bouteilles 19L', 'driver': 'Rachid Bouzid', 'status': 'Annulé', 'date': '12 avr. 2026', 'time': '09:00'},
    {'id': '#CMD-0038', 'client': 'Mohamed Ait', 'address': '3 Lotissement Saada, Constantine', 'qty': '1 bonbonne 10L', 'driver': 'Non assigné', 'status': 'En attente', 'date': '11 avr. 2026', 'time': '08:30'},
  ];
  String _filter = 'Tous';
  final List<String> _drivers = ['Hamza Tizi', 'Youcef Mansouri', 'Rachid Bouzid', 'Nassim Oubira'];

  Color _statusColor(String s) {
    switch (s) {
      case 'Livré': return Colors.green;
      case 'En cours': return Colors.blue;
      case 'Annulé': return Colors.red;
      default: return Colors.orange;
    }
  }

  void _showDetail(Map<String, dynamic> order) {
    String selectedDriver = _drivers.contains(order['driver']) ? order['driver'] : _drivers[0];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(order['id'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _statusColor(order['status']).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(order['status'], style: TextStyle(color: _statusColor(order['status']), fontWeight: FontWeight.w600)),
                  ),
                ]),
                const Divider(height: 24),
                _row(Icons.person_outline, 'Client', order['client']),
                _row(Icons.location_on_outlined, 'Adresse', order['address']),
                _row(Icons.water_drop_outlined, 'Article', order['qty']),
                _row(Icons.calendar_today_outlined, 'Date', '${order['date']} à ${order['time']}'),
                const SizedBox(height: 16),
                const Text('Réassigner le chauffeur :', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedDriver,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _drivers.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setModal(() => selectedDriver = v!),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: order['status'] == 'Annulé' || order['status'] == 'Livré' ? null : () {
                        setState(() => order['status'] = 'Annulé');
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${order['id']} annulée'), backgroundColor: Colors.red));
                      },
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Annuler', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => order['driver'] = selectedDriver);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chauffeur réassigné')));
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmer'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: Colors.grey),
      const SizedBox(width: 10),
      Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final statusList = ['Tous', 'En attente', 'En cours', 'Livré', 'Annulé'];
    final filtered = _filter == 'Tous' ? _orders : _orders.where((o) => o['status'] == _filter).toList();
    return Scaffold(
      appBar: buildAppBar('Commandes'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statusList.map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: Colors.orange.withOpacity(0.15),
                      checkmarkColor: Colors.orange,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = filtered[i];
                final color = _statusColor(o['status']);
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.receipt_long, color: Colors.orange.shade700),
                    ),
                    title: Row(children: [
                      Text(o['id'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(o['status'], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 4),
                      Text(o['client'], style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${o['qty']} · ${o['date']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('Chauffeur : ${o['driver']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                    onTap: () => _showDetail(o),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== AVERTISSEMENTS ====================
class WarningsScreen extends StatefulWidget {
  const WarningsScreen({super.key});
  @override
  State<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends State<WarningsScreen> {
  final List<Map<String, dynamic>> _warnings = [
    {'title': 'Retard de livraison', 'user': 'Chauffeur : Rachid Bouzid', 'time': 'Il y a 2h', 'level': 'Moyen', 'treated': false},
    {'title': 'Paiement non confirmé', 'user': 'Client : Mohamed Ait', 'time': 'Il y a 5h', 'level': 'Urgent', 'treated': false},
    {'title': 'Stock faible (Bouteille 10L)', 'user': 'Système', 'time': 'Hier 09:14', 'level': 'Info', 'treated': false},
    {'title': 'Tentative de connexion suspecte', 'user': 'IP : 41.109.x.x', 'time': 'Hier 02:31', 'level': 'Urgent', 'treated': true},
    {'title': 'Compte inactif depuis 30j', 'user': 'Client : Karim Djamel', 'time': 'Il y a 3j', 'level': 'Faible', 'treated': false},
  ];

  Color _levelColor(String l) {
    switch (l) {
      case 'Urgent': return Colors.red;
      case 'Moyen': return Colors.orange;
      case 'Faible': return Colors.blue;
      default: return Colors.teal;
    }
  }

  IconData _levelIcon(String l) {
    switch (l) {
      case 'Urgent': return Icons.error_outline;
      case 'Moyen': return Icons.warning_amber_outlined;
      case 'Faible': return Icons.info_outline;
      default: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar('Avertissements'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSignalementDialog(context),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Envoyer signalement'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _warnings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final w = _warnings[i];
          final color = _levelColor(w['level']);
          final treated = w['treated'] as bool;
          return Opacity(
            opacity: treated ? 0.5 : 1.0,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_levelIcon(w['level']), color: color),
                ),
                title: Text(w['title'], style: TextStyle(fontWeight: FontWeight.w600, decoration: treated ? TextDecoration.lineThrough : null)),
                subtitle: Text('${w['user']} · ${w['time']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(w['level'], style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => w['treated'] = !treated),
                    child: Text(treated ? 'Traité ✓' : 'Marquer traité',
                        style: TextStyle(fontSize: 10, color: treated ? Colors.green : Colors.grey, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==================== RÉCLAMATIONS ====================
class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});
  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  final List<Map<String, dynamic>> _claims = [
    {'id': '#REC-011', 'client': 'Sara Khalil', 'subject': 'Bouteille endommagée à la livraison', 'status': 'Ouverte', 'date': '14 avr.', 'priority': 'Haute'},
    {'id': '#REC-010', 'client': 'Fatima Zohra', 'subject': 'Livraison non reçue', 'status': 'En traitement', 'date': '13 avr.', 'priority': 'Haute'},
    {'id': '#REC-009', 'client': 'Ahmed Benali', 'subject': 'Mauvaise quantité livrée', 'status': 'Résolue', 'date': '10 avr.', 'priority': 'Normale'},
    {'id': '#REC-008', 'client': 'Mohamed Ait', 'subject': 'Chauffeur impoli', 'status': 'Fermée', 'date': '08 avr.', 'priority': 'Basse'},
  ];

  Color _statusColor(String s) {
    switch (s) {
      case 'Ouverte': return Colors.red;
      case 'En traitement': return Colors.orange;
      case 'Résolue': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _showClaimDetail(Map<String, dynamic> c) {
    String currentStatus = c['status'];
    final replyCtrl = TextEditingController();
    final statuses = ['Ouverte', 'En traitement', 'Résolue', 'Fermée'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c['id'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _statusColor(currentStatus).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(currentStatus, style: TextStyle(color: _statusColor(currentStatus), fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(c['subject'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${c['client']} · ${c['date']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const Divider(height: 24),
                const Text('Changer le statut :', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: statuses.map((s) {
                    final sel = currentStatus == s;
                    return ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      selectedColor: _statusColor(s).withOpacity(0.2),
                      labelStyle: TextStyle(color: sel ? _statusColor(s) : Colors.black),
                      onSelected: (_) => setModal(() => currentStatus = s),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Répondre au client :', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: replyCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Écrivez votre réponse ici...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.reply_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); showSignalementDialog(context, defaultTarget: c['client']); },
                      icon: const Icon(Icons.flag_outlined, color: Colors.red, size: 16),
                      label: const Text('Signalement', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => c['status'] = currentStatus);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réclamation mise à jour')));
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Enregistrer', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar('Réclamations'),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _claims.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = _claims[i];
          final color = _statusColor(c['status']);
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(c['id'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c['priority'] == 'Haute' ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(c['priority'], style: TextStyle(
                        fontSize: 10,
                        color: c['priority'] == 'Haute' ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      )),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(c['status'], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(c['subject'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${c['client']} · ${c['date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(children: [
                    OutlinedButton(onPressed: () => _showClaimDetail(c), child: const Text('Voir & traiter')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => showSignalementDialog(context, defaultTarget: c['client']),
                      icon: const Icon(Icons.flag_outlined, size: 14, color: Colors.red),
                      label: const Text('Signaler', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==================== NOTES & AVIS ====================
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final List<Map<String, dynamic>> _reviews = [
    {'client': 'Fatima Zohra', 'driver': 'Hamza Tizi', 'note': 5, 'comment': 'Livraison rapide, chauffeur très poli. Parfait !', 'hidden': false},
    {'client': 'Ahmed Benali', 'driver': 'Youcef Mansouri', 'note': 4, 'comment': 'Bon service en général, petit retard.', 'hidden': false},
    {'client': 'Sara Khalil', 'driver': 'Rachid Bouzid', 'note': 2, 'comment': 'Bouteille sale à la livraison, déçue.', 'hidden': false},
    {'client': 'Mohamed Ait', 'driver': 'Nassim Oubira', 'note': 5, 'comment': 'Excellent, je recommande vivement.', 'hidden': false},
    {'client': 'Karim Djamel', 'driver': 'Hamza Tizi', 'note': 1, 'comment': 'Très mauvaise expérience, je ne commanderai plus.', 'hidden': false},
  ];
  int? _filterNote;
  String? _filterDriver;

  List<String> get _allDrivers => _reviews.map((r) => r['driver'] as String).toSet().toList();

  @override
  Widget build(BuildContext context) {
    final Map<String, List<int>> driverNotes = {};
    for (final r in _reviews) {
      driverNotes.putIfAbsent(r['driver'], () => []).add(r['note'] as int);
    }
    var filtered = _reviews.where((r) {
      if (_filterNote != null && r['note'] != _filterNote) return false;
      if (_filterDriver != null && r['driver'] != _filterDriver) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: buildAppBar('Notes & avis'),
      body: Column(
        children: [
          SizedBox(
            height: 90,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              scrollDirection: Axis.horizontal,
              itemCount: driverNotes.entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final entry = driverNotes.entries.elementAt(i);
                final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
                final selected = _filterDriver == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _filterDriver = selected ? null : entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.amber.withOpacity(0.2) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: selected ? Border.all(color: Colors.amber) : null,
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(entry.key.split(' ').first, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${avg.toStringAsFixed(1)}★', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      Text('${entry.value.length} avis', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(label: const Text('Tous'), selected: _filterNote == null,
                      onSelected: (_) => setState(() => _filterNote = null)),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) {
                    final n = i + 1;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text('$n★'),
                        selected: _filterNote == n,
                        onSelected: (_) => setState(() => _filterNote = _filterNote == n ? null : n),
                        selectedColor: Colors.amber.withOpacity(0.2),
                        checkmarkColor: Colors.amber,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = filtered[i];
                final note = r['note'] as int;
                final hidden = r['hidden'] as bool;
                return Opacity(
                  opacity: hidden ? 0.4 : 1.0,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(radius: 18, backgroundColor: Colors.amber.shade100,
                                child: Text((r['client'] as String)[0], style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r['client'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Chauffeur : ${r['driver']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ])),
                            Row(children: List.generate(5, (j) => Icon(j < note ? Icons.star : Icons.star_border, size: 18, color: Colors.amber))),
                          ]),
                          const SizedBox(height: 10),
                          Text(r['comment'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton.icon(
                              onPressed: () => setState(() => r['hidden'] = !hidden),
                              icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16),
                              label: Text(hidden ? 'Afficher' : 'Masquer', style: const TextStyle(fontSize: 12)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== JOURNAL D'ACTIVITÉ ====================
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filter = 'Tous';

  final List<Map<String, dynamic>> _logs = [
    {'action': 'Commande créée', 'detail': '#CMD-0042 par Ahmed Benali', 'time': '15 avr. 10:23', 'author': 'Système', 'type': 'Commande', 'icon': Icons.add_circle_outline, 'color': Colors.green},
    {'action': 'Chauffeur assigné', 'detail': 'Hamza Tizi → #CMD-0042', 'time': '15 avr. 10:31', 'author': 'Admin', 'type': 'Commande', 'icon': Icons.person_pin_outlined, 'color': Colors.blue},
    {'action': 'Commande livrée', 'detail': '#CMD-0041 confirmée', 'time': '14 avr. 15:10', 'author': 'Système', 'type': 'Commande', 'icon': Icons.check_circle_outline, 'color': Colors.teal},
    {'action': 'Réclamation ouverte', 'detail': '#REC-011 par Sara Khalil', 'time': '14 avr. 16:45', 'author': 'Client', 'type': 'Réclamation', 'icon': Icons.report_problem_outlined, 'color': Colors.orange},
    {'action': 'Compte suspendu', 'detail': 'Mohamed Ait - motif : impayé', 'time': '13 avr. 09:00', 'author': 'Admin', 'type': 'Compte', 'icon': Icons.block_outlined, 'color': Colors.red},
    {'action': 'Connexion admin', 'detail': 'IP : 41.109.12.34', 'time': '13 avr. 08:52', 'author': 'Admin', 'type': 'Connexion', 'icon': Icons.login_outlined, 'color': Colors.grey},
    {'action': 'Signalement envoyé', 'detail': 'Rachid Bouzid - retard répété', 'time': '12 avr. 14:00', 'author': 'Admin', 'type': 'Signalement', 'icon': Icons.flag_outlined, 'color': Colors.red},
  ];

  @override
  Widget build(BuildContext context) {
    final types = ['Tous', 'Commande', 'Réclamation', 'Compte', 'Connexion', 'Signalement'];
    final filtered = _filter == 'Tous' ? _logs : _logs.where((l) => l['type'] == _filter).toList();
    return Scaffold(
      appBar: buildAppBar("Journal d'activité"),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: types.map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: Colors.teal.withOpacity(0.15),
                      checkmarkColor: Colors.teal,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Journal exporté (simulation)'))),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Exporter', style: TextStyle(fontSize: 13)),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final log = filtered[i];
                final color = log['color'] as Color;
                final isLast = i == filtered.length - 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(log['icon'] as IconData, color: color, size: 20),
                      ),
                      if (!isLast) Container(width: 2, height: 44, color: Colors.grey.shade200),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(log['action'], style: const TextStyle(fontWeight: FontWeight.w600))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(log['author'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          ]),
                          Text(log['detail'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(log['time'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== PARAMÈTRES ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = false;
  bool _autoAssign = true;
  String _selectedLang = 'Français';
  final List<String> _zones = ['Alger Centre', 'Bab Ezzouar', 'Kouba', 'Hussein Dey', 'El Harrach'];
  final TextEditingController _zoneCtrl = TextEditingController();

  void _showZonesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Zones de livraison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._zones.map((z) => ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Color(0xFF1E3A8A)),
                title: Text(z),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () { setState(() => _zones.remove(z)); setModal(() {}); },
                ),
              )),
              const Divider(),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _zoneCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nouvelle zone...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_zoneCtrl.text.trim().isNotEmpty) {
                      setState(() => _zones.add(_zoneCtrl.text.trim()));
                      setModal(() {});
                      _zoneCtrl.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  child: const Text('Ajouter'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showHoursDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Horaires de service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hourRow('Lundi – Vendredi', '07:00 – 20:00'),
            _hourRow('Samedi', '08:00 – 18:00'),
            _hourRow('Dimanche', 'Fermé'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horaires enregistrés')));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Widget _hourRow(String day, String hours) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(day, style: const TextStyle(fontWeight: FontWeight.w500))),
      Text(hours, style: const TextStyle(color: Colors.grey)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar('Paramètres'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Général'),
          _buildToggleTile(Icons.dark_mode_outlined, 'Mode sombre', _darkMode, (v) => setState(() => _darkMode = v)),
          _buildToggleTile(Icons.notifications_outlined, 'Notifications push', _notifications, (v) => setState(() => _notifications = v)),
          _buildDropdownTile(Icons.language_outlined, 'Langue', _selectedLang, ['Français', 'العربية', 'English'], (v) => setState(() => _selectedLang = v!)),
          const SizedBox(height: 16),
          _sectionHeader('Livraison'),
          _buildToggleTile(Icons.autorenew_outlined, 'Assignation automatique', _autoAssign, (v) => setState(() => _autoAssign = v)),
          _buildActionTile(Icons.timer_outlined, 'Horaires de service', _showHoursDialog),
          _buildActionTile(Icons.map_outlined, 'Gérer les zones (${_zones.length} actives)', _showZonesDialog),
          const SizedBox(height: 16),
          _sectionHeader('Compte administrateur'),
          _buildActionTile(Icons.lock_outline, 'Changer le mot de passe', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redirection vers changement de MDP')));
          }),
          _buildActionTile(Icons.logout, 'Se déconnecter', () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => Loginpage()),
                  (route) => false, // Supprime tout l'historique de navigation
            );
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
  );

  Widget _buildToggleTile(IconData icon, String title, bool value, Function(bool) onChanged) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: SwitchListTile(
      secondary: Icon(icon, color: const Color(0xFF1E3A8A)),
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1E3A8A),
    ),
  );

  Widget _buildDropdownTile(IconData icon, String title, String value, List<String> items, Function(String?) onChanged) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF1E3A8A)),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    ),
  );

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap, {Color? color}) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF1E3A8A)),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

// ==================== ÉCRAN FALLBACK ====================
class SectionScreen extends StatelessWidget {
  final String title;
  const SectionScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(title),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 60),
                Icon(Icons.dashboard_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 24),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const Text('Contenu à venir.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}