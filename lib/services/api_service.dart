import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://pfe-backend-nwmy.onrender.com';

  // Stored after login
  static String? token;
  static String? userId;
  static String? userRole;

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
  // HELPERS
  // ─────────────────────────────────────────

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {
        'error': 'Server returned unexpected response (status ${response.statusCode})',
      };
    }
  }

  static List<dynamic> _decodeList(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // AUTH  →  /api/auth
  // ─────────────────────────────────────────

  /// Register a new user
  /// Returns { msg, userId } — then call chooseRole() with the userId
  static Future<Map<String, dynamic>> register({
    required String nom,
    required String prenom,
    required String telephone,
    required String email,
    required String password,
    required String adresse,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'nom': nom,
          'prenom': prenom,
          'telephone': telephone,
          'email': email,
          'password': password,
          'adresse': adresse,
        }),
      );
      final data = _decode(response);
      if (data['userId'] != null) userId = data['userId'];
      return data;
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Login — saves token, userId, userRole automatically
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = _decode(response);
      if (data['token'] != null)        token    = data['token'];
      if (data['user']?['id'] != null)  userId   = data['user']['id'];
      if (data['user']?['role'] != null) userRole = data['user']['role'];
      return data;
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Choose role after register — can only be called ONCE per user
  /// role must be: "client" or "fournisseur"
  /// ✅ FIXED: now saves the NEW token returned by backend (token contains role)
  static Future<Map<String, dynamic>> chooseRole({
    required String userId,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/choose-role'),
        headers: _headers,
        body: jsonEncode({'userId': userId, 'role': role}),
      );
      final data = _decode(response);
      if (data['role'] != null)  userRole      = data['role'];
      if (data['token'] != null) token         = data['token']; // ✅ save new token with role
      return data;
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────
  // CLIENT  →  /api/clients
  // ─────────────────────────────────────────

  /// Get list of all fournisseurs (client only)
  static Future<List<dynamic>> getFournisseurs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/clients/fournisseurs'),
        headers: _authHeaders,
      );
      return _decodeList(response);
    } on SocketException {
      return [];
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }
  /// Get fournisseur's own profile including fournisseurInfo.quantiteEau
  static Future<Map<String, dynamic>> getMyInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/fournisseurs/me'),
        headers: _authHeaders,
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error.'};
    } on TimeoutException {
      return {'error': 'Request timed out.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  // ─────────────────────────────────────────
  // FOURNISSEUR  →  /api/fournisseurs
  // ─────────────────────────────────────────

  /// Add fournisseur info — quantiteEau & wilayas (fournisseur only)
  static Future<Map<String, dynamic>> addFournisseurInfo({
    required double quantiteEau,
    required List<String> wilayas,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/fournisseurs/add-info'),
        headers: _authHeaders,
        body: jsonEncode({
          'quantiteEau': quantiteEau,
          'wilayas': wilayas,
        }),
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Update fournisseur GPS position (fournisseur only)
  static Future<Map<String, dynamic>> updatePosition({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/fournisseurs/position'),
        headers: _authHeaders,
        body: jsonEncode({'lat': lat, 'lon': lon}),
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Set fournisseur offline (fournisseur only)
  static Future<Map<String, dynamic>> setOffline() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/fournisseurs/offline'),
        headers: _authHeaders,
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────
  // CHAUFFEUR  →  /api/chauffeurs
  // ─────────────────────────────────────────

  /// Add a new chauffeur (fournisseur only)
  static Future<Map<String, dynamic>> addChauffeur({
    required String nom,
    required String telephone,
    required double capaciteCamion,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chauffeurs/add'),
        headers: _authHeaders,
        body: jsonEncode({
          'nom': nom,
          'telephone': telephone,
          'capaciteCamion': capaciteCamion,
        }),
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get my chauffeurs (fournisseur only)
  static Future<List<dynamic>> getMyChauffeurs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chauffeurs/my'),
        headers: _authHeaders,
      );
      return _decodeList(response);
    } on SocketException {
      return [];
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // COMMANDE  →  /api/commandes
  // ─────────────────────────────────────────

  /// Create a new commande (client only)
  static Future<Map<String, dynamic>> addCommande({
    required double capacite,
    required double prix,
    double? lat,
    double? lon,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/commandes/add'),
        headers: _authHeaders,
        body: jsonEncode({
          'capacite': capacite,
          'prix': prix,
          if (lat != null) 'lat': lat,
          if (lon != null) 'lon': lon,
        }),
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get my commandes (client only)
  static Future<List<dynamic>> getMyCommandes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/commandes/my'),
        headers: _authHeaders,
      );
      return _decodeList(response);
    } on SocketException {
      return [];
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get pending commandes only — "en attente" (fournisseur only)
  static Future<List<dynamic>> getPendingCommandes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/commandes/pending'),
        headers: _authHeaders,
      );
      return _decodeList(response);
    } on SocketException {
      return [];
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// ✅ Get ALL commandes with optional status filter (fournisseur only)
  /// This is what OrdersScreen should use — shows all statuses
  /// status: "en attente" | "en livraison" | "livrée" | "annulée"
  static Future<List<dynamic>> getCommandes({String? status}) async {
    try {
      final uri = status != null
          ? Uri.parse('$baseUrl/api/commandes?status=${Uri.encodeComponent(status)}')
          : Uri.parse('$baseUrl/api/commandes');
      final response = await http.get(uri, headers: _authHeaders);
      print('GET /commandes status: ${response.statusCode}');
      print('GET /commandes body: ${response.body}');
      print('GET /commandes token: $token');
      return _decodeList(response);
    } on SocketException {
      return [];
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Assign a chauffeur to a commande (fournisseur only)
  static Future<Map<String, dynamic>> assignCommande({
    required String commandeId,
    required String chauffeurId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/commandes/assign/$commandeId/$chauffeurId'),
        headers: _authHeaders,
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Mark commande as delivered (fournisseur only)
  static Future<Map<String, dynamic>> markLivree(String commandeId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/commandes/livree/$commandeId'),
        headers: _authHeaders,
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Cancel a commande (client only)
  static Future<Map<String, dynamic>> cancelCommande(String commandeId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/commandes/cancel/$commandeId'),
        headers: _authHeaders,
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────
  // AI  →  /api/ai
  // ─────────────────────────────────────────

  /// Optimise delivery route via Python AI service
  static Future<Map<String, dynamic>> optimiseRoute(
      Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/optimise'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _decode(response);
    } on SocketException {
      return {'error': 'Connection error. Check your internet.'};
    } on TimeoutException {
      return {'error': 'Request timed out. Try again.'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}