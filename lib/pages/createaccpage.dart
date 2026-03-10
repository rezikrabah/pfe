import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:test2/pages/Loginpage.dart';
import 'package:test2/pages/RoleSelectionScreen.dart';
import '../services/api_service.dart';

void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: createaccpage()
    )
);

class createaccpage extends StatefulWidget {
  const createaccpage({super.key});

  @override
  State<createaccpage> createState() => _createaccpageState();
}

class _createaccpageState extends State<createaccpage> {

  // ── Controllers ──
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  // ── Register function ──
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Step 1 — register user (no role yet)
    final result = await ApiService.register(
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      telephone: _phoneController.text.trim(),
      adresse: _adresseController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result['error'] != null) {
      // Network or server error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result['userId'] != null) {
      // Step 2 — go to role selection screen with userId
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Please choose your role.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoleSelectionScreen(userId: result['userId']),
        ),
      );
    } else {
      // Server returned an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['msg'] ?? 'Registration failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Reusable input field ──
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
        prefixIcon: Icon(icon, color: Color(0xFF00C8F0)),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFF0099CC), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFF00C8F0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071628),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        title: const Text("CREATE YOUR ACCOUNT",
          style: TextStyle(color: Color(0xFFB4DCE6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        backgroundColor: const Color(0xFF04111F),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.water_drop, size: 30, color: Color(0xFF1E88E5)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 10),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(
                    'https://img.freepik.com/premium-vector/water-vector-logo-design-white-background_1277164-15228.jpg',
                  ),
                ),
              ),
              const Text('sign up',
                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const Text('add your details to sign up',
                style: TextStyle(color: Color(0xFF9EC7CF), fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              // ── Last name ──
              _buildField(
                controller: _nomController,
                label: 'last name',
                hint: 'enter your last name',
                icon: Icons.badge,
                validator: (v) => v!.isEmpty ? 'please enter your last name' : null,
              ),
              const SizedBox(height: 10),

              // ── First name ──
              _buildField(
                controller: _prenomController,
                label: 'first name',
                hint: 'enter your first name',
                icon: Icons.person,
                validator: (v) => v!.isEmpty ? 'please enter your first name' : null,
              ),
              const SizedBox(height: 10),

              // ── Email ──
              _buildField(
                controller: _emailController,
                label: 'email',
                hint: 'enter your email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.isEmpty) return 'please enter your email';
                  if (!v.contains('@')) return 'enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // ── Phone ──
              _buildField(
                controller: _phoneController,
                label: 'phone number',
                hint: 'enter your phone number',
                icon: Icons.phone,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'please enter your phone number' : null,
              ),
              const SizedBox(height: 10),

              // ── Password ──
              _buildField(
                controller: _passwordController,
                label: 'password',
                hint: 'enter your password',
                icon: Icons.password,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v!.isEmpty) return 'please enter your password';
                  if (v.length < 6) return 'password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // ── Address ──
              _buildField(
                controller: _adresseController,
                label: 'adresse',
                hint: 'please enter your address',
                icon: Icons.map,
                validator: (v) => v!.isEmpty ? 'please enter your address' : null,
              ),
              const SizedBox(height: 20),

              // ── Sign Up Button ──
              Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : TextButton.icon(
                  onPressed: _register,
                  label: const Text(
                    'sign up',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              const Text('already have account?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Loginpage()),
                  );
                },
                child: const Text('login',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}