import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/couleurs_app.dart';
import '../citoyen/parametres.dart';
import 'package:shared_preferences/shared_preferences.dart';
class EcranProfilAdmin extends StatefulWidget {
  const EcranProfilAdmin({super.key});

  @override
  State<EcranProfilAdmin> createState() => _EcranProfilAdminState();
}

class _EcranProfilAdminState extends State<EcranProfilAdmin> {
  String _nomPrenom = "";
  String _email = "";
  String _servicePublic = "Service non défini";
  String _wilaya = "Wilaya non définie";

  int _incidentsResolusCount = 0;
  int _incidentsEnCoursCount = 0;
  int _signalementsPasTraitesCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerProfilAgent();
  }

  Future<void> _chargerProfilAgent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      final response = await ApiService.getUserProfile(accessToken as String);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("PROFILE AGENT DATA = $data");

        final firstName = data['first_name']?.toString() ?? "";
        final lastName = data['last_name']?.toString() ?? "";

        setState(() {
          _nomPrenom = "$firstName $lastName".trim();

          if (_nomPrenom.isEmpty) {
            _nomPrenom = "Agent FixCity";
          }

          _email = data['email']?.toString() ?? "";

          _servicePublic =
              data['service_public']?.toString() ?? "Service non défini";

          _wilaya = data['wilaya']?.toString() ?? "Wilaya non définie";

          _signalementsPasTraitesCount =
              int.tryParse(data['signalements_pas_traites']?.toString() ?? '0') ?? 0;

          _incidentsEnCoursCount =
              int.tryParse(data['signalements_en_cours']?.toString() ?? '0') ?? 0;

          _incidentsResolusCount =
              int.tryParse(data['signalements_resolus']?.toString() ?? '0') ?? 0;

          _isLoading = false;
        });
      } else if (response.statusCode == 401){
        // Token d'accès expiré, essayer de rafraîchir le token
        final refreshTokenResponse = await ApiService.refreshToken(refreshToken as String);
        if (refreshTokenResponse.statusCode != 200) {
          // Le rafraîchissement a échoué, rediriger vers le login
          await prefs.clear();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
          return;
        }
        final data = jsonDecode(refreshTokenResponse.body);
        final nouveauAccessToken = data['access'];
        await prefs.setString('access_token', nouveauAccessToken);

        // Réessayer de charger le profil avec le nouveau token
        await _chargerProfilAgent();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deconnexion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: CouleursApp.background,
        body: Center(
          child: CircularProgressIndicator(
            color: CouleursApp.primaire,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CouleursApp.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(height: 200, color: CouleursApp.primaire),
                Positioned(
                  bottom: -1,
                  left: 0,
                  right: 0,
                  child: ClipPath(
                    clipper: ArcheInverseeClipper(),
                    child: Container(height: 80, color: CouleursApp.background),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9FAD9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        size: 70,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              _nomPrenom,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CouleursApp.textPrimaire,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F9EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _email,
                style: const TextStyle(
                  color: CouleursApp.primaire,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildInfoCard("Wilaya :", _wilaya),
                  const SizedBox(width: 16),
                  _buildInfoCard("Service public :", _servicePublic),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Statistiques signalements",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: CouleursApp.textSecondaire,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatSimple(
                      "Pas traités",
                      "$_signalementsPasTraitesCount",
                      Colors.red,
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildStatSimple(
                      "En cours",
                      "$_incidentsEnCoursCount",
                      Colors.orange,
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildStatSimple(
                      "Résolus",
                      "$_incidentsResolusCount",
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Divider(indent: 24, endIndent: 24),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Informations",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: CouleursApp.textSecondaire,
                  ),
                ),
              ),
            ),

            _buildItemOption(
              icon: Icons.info_outline_rounded,
              titre: "À propos de FixCity",
              sousTitre: "Conditions, contact et mentions légales",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EcranParametres(),
                  ),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(indent: 24, endIndent: 24),
            ),

            _buildItemOption(
              icon: Icons.logout,
              titre: "Se déconnecter",
              sousTitre: "",
              couleurIcone: Colors.redAccent,
              onTap: _deconnexion,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CouleursApp.bordure),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSimple(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildItemOption({
    required IconData icon,
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
    Color? couleurIcone,
  }) {
    final Color couleurTheme = couleurIcone ?? CouleursApp.primaire;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: couleurTheme.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: couleurTheme, size: 22),
        ),
        title: Text(
          titre,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: sousTitre.isNotEmpty
            ? Text(sousTitre, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class ArcheInverseeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.moveTo(0, size.height);

    final pointDeControle = Offset(size.width / 2, -25);
    final pointFinal = Offset(size.width, size.height);

    path.quadraticBezierTo(
      pointDeControle.dx,
      pointDeControle.dy,
      pointFinal.dx,
      pointFinal.dy,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}