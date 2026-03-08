import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'forgotpassword.dart';
import 'RoleSelectionScreen.dart';
import '../services/api_service.dart';

void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Loginpage()
    )
);

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {

  // ── Controllers to read what user types ──
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Login function ──
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.clientLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (result['token'] != null) {
        // ✅ Login successful
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to next screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
        );
      } else {
        // ❌ Login failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg'] ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error. Check your internet.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C2A34),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        title: const Text("log your account", style: TextStyle(color: Color(0xFFEAFBFF))),
        backgroundColor: const Color(0xFF0B3C49),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.water_drop, size: 30, color: Color(0xFF1E88E5)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Form(
            key: _formKey,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                    fadeInDuration: const Duration(milliseconds: 200),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                Container(
                  width: double.infinity,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 50),
                  child: const CircleAvatar(
                    radius: 30,
                    backgroundImage: CachedNetworkImageProvider(
                      'https://img.freepik.com/premium-vector/water-vector-logo-design-white-background_1277164-15228.jpg',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 150, left: 10, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('LOGIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text('add your details to login',
                        style: TextStyle(
                          color: Color(0xFFB8E3F0),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Email ──
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'email',
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          hintText: 'enter your email',
                          hintStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                          prefixIcon: const Icon(Icons.email, color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: const BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2),
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
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value!.isEmpty) return 'please enter your email';
                          if (!value.contains('@')) return 'enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      // ── Password ──
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'password',
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          hintText: 'enter your password',
                          hintStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          prefixIcon: const Icon(Icons.password, color: Colors.white),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: const BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2),
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
                        validator: (value) {
                          if (value!.isEmpty) return 'please enter your password';
                          if (value.length < 6) return 'password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Login Button ──
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
                            : TextButton(
                          onPressed: _login,
                          child: const Text(
                            'log in',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
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
    );
  }
}