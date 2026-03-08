import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 👇 Change this to your PC's IP address when testing on a real phone
  // For Android emulator use: http://10.0.2.2:3000
  // For real phone use: http://YOUR_PC_IP:3000 (find with ipconfig in CMD)
  static const String baseUrl = 'https://pfe-backend-nwmy.onrender.com';

  // Store token after login
  static String? token;

  // ─────────────────────────────────────────
  // HEADERS
  // ─────────────────────────────────────────

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ─────────────────────────────────────────
  // CLIENT
  // ─────────────────────────────────────────

  /// Register a new client
  static Future<Map<String, dynamic>> clientRegister({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    required String telephone,
    required String adresse,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/clients/register'),
      headers: _headers,
      body: jsonEncode({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password': password,
        'telephone': telephone,
        'adresse': adresse,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Login as client — saves token automatically
  static Future<Map<String, dynamic>> clientLogin({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/clients/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (data['token'] != null) token = data['token'];
    return data;
  }

  /// Get client profile (requires login)
  static Future<Map<String, dynamic>> clientProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/clients/profile'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }

  // ─────────────────────────────────────────
  // FOURNISSEUR
  // ─────────────────────────────────────────

  /// Register a new fournisseur
  static Future<Map<String, dynamic>> fournisseurRegister({
    required String nom,
    required String email,
    required String password,
    required String telephone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/fournisseurs/register'),
      headers: _headers,
      body: jsonEncode({
        'nom': nom,
        'email': email,
        'password': password,
        'telephone': telephone,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Login as fournisseur — saves token automatically
  static Future<Map<String, dynamic>> fournisseurLogin({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/fournisseurs/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (data['token'] != null) token = data['token'];
    return data;
  }

  // ─────────────────────────────────────────
  // CHAUFFEUR
  // ─────────────────────────────────────────

  /// Add a new chauffeur (fournisseur only)
  static Future<Map<String, dynamic>> addChauffeur({
    required String nom,
    required String telephone,
    required double capaciteCamion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/chauffeurs/add'),
      headers: _authHeaders,
      body: jsonEncode({
        'nom': nom,
        'telephone': telephone,
        'capaciteCamion': capaciteCamion,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Get my chauffeurs (fournisseur only)
  static Future<List<dynamic>> getMyChauffeurs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/chauffeurs/my'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }

  // ─────────────────────────────────────────
  // COMMANDE
  // ─────────────────────────────────────────

  /// Create a new commande (client only)
  static Future<Map<String, dynamic>> addCommande({
    required double capacite,
    required double prix,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/commandes/add'),
      headers: _authHeaders,
      body: jsonEncode({'capacite': capacite, 'prix': prix}),
    );
    return jsonDecode(response.body);
  }

  /// Get my commandes (client only)
  static Future<List<dynamic>> getMyCommandes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/commandes/my'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }

  /// Get pending commandes (fournisseur only)
  static Future<List<dynamic>> getPendingCommandes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/commandes/pending'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }

  /// Get all commandes with optional status filter (fournisseur only)
  /// status: "en attente" | "en livraison" | "livrée" | "annulée"
  static Future<List<dynamic>> getAllCommandes({String? status}) async {
    final uri = status != null
        ? Uri.parse('$baseUrl/api/commandes?status=$status')
        : Uri.parse('$baseUrl/api/commandes');
    final response = await http.get(uri, headers: _authHeaders);
    return jsonDecode(response.body);
  }

  /// Assign a chauffeur to a commande (fournisseur only)
  static Future<Map<String, dynamic>> assignCommande({
    required String commandeId,
    required String chauffeurId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/commandes/assign/$commandeId/$chauffeurId'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }

  /// Mark commande as delivered (fournisseur only)
  static Future<Map<String, dynamic>> markLivree(String commandeId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/commandes/livree/$commandeId'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }

  /// Cancel a commande (client only)
  static Future<Map<String, dynamic>> cancelCommande(String commandeId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/commandes/cancel/$commandeId'),
      headers: _authHeaders,
    );
    return jsonDecode(response.body);
  }
}