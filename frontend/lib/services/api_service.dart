import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Map<String, String> jsonHeaders() {
    return {
      'Content-Type': 'application/json',
    };
  }

  static Map<String, String> authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------- AUTHENTIFICATION ----------------

  static Future<http.Response> login(String email, String password) async {
    return await http.post(
      Uri.parse('$baseUrl/app/token'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
  }

  static Future<http.Response> refreshToken(String refresh) async {
    return await http.post(
      Uri.parse('$baseUrl/app/token/refresh'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'refresh': refresh,
      }),
    );
  }

  // ---------------- INSCRIPTION + OTP ----------------

  static Future<http.Response> sendRegisterOtp(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/app/register/send-otp'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'email': email,
      }),
    );
  }

  static Future<http.Response> verifyRegisterOtp(
    String email,
    String otp,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/app/register/verify-otp'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );
  }

  static Future<http.Response> registerConfirm(
    Map<String, dynamic> data,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/app/register/confirm'),
      headers: jsonHeaders(),
      body: jsonEncode(data),
    );
  }

  // ---------------- INCIDENTS CITOYEN ----------------

  static Future<http.Response> creerIncident(
    Map<String, dynamic> data,
    String token,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/app/creer-incident'),
      headers: authHeaders(token),
      body: jsonEncode(data),
    );
  }

  static Future<http.Response> listeIncidents(String token) async {
    return await http.get(
      Uri.parse('$baseUrl/app/liste-incidents'),
      headers: authHeaders(token),
    );
  }

  static Future<http.Response> listeIncidentsProches(
    String token,
    double lat,
    double long,
  ) async {
    return await http.get(
      Uri.parse('$baseUrl/app/incidents-proches?lat=$lat&long=$long'),
      headers: authHeaders(token),
    );
  }

  // ---------------- INCIDENTS AGENT / ADMIN ----------------

  static Future<http.Response> listeIncidentsService(String token) async {
    return await http.get(
      Uri.parse('$baseUrl/app/liste-incidents-service'),
      headers: authHeaders(token),
    );
  }

  static Future<http.Response> getIncident(int id, String token) async {
    return await http.get(
      Uri.parse('$baseUrl/app/incident/$id'),
      headers: authHeaders(token),
    );
  }

  static Future<http.Response> updateStatutIncident(
    int id,
    String statut,
    String token,
  ) async {
    return await http.patch(
      Uri.parse('$baseUrl/app/update-incident/$id'),
      headers: authHeaders(token),
      body: jsonEncode({
        'statut': statut,
      }),
    );
  }

  // ---------------- MOT DE PASSE OUBLIÉ ----------------

  static Future<http.Response> passwordResetSendOtp(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/app/password-reset/send-otp'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'email': email,
      }),
    );
  }

  static Future<http.Response> passwordResetVerify(
    String email,
    String otp,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/app/password-reset/verify-otp'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );
  }

  static Future<http.Response> passwordResetConfirm(
    String email,
    String newPassword,
  ) async {
    return await http.post(
      Uri.parse('$baseUrl/app/password-reset/confirm'),
      headers: jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'password': newPassword,
      }),
    );
  }

  // ---------------- PROFIL ----------------

  static Future<http.Response> getUserProfile(String token) async {
    return await http.get(
      Uri.parse('$baseUrl/app/user-profile'),
      headers: authHeaders(token),
    );
  }
}