import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/couleurs_app.dart';
import '../../services/api_service.dart';
import '../citoyen/parametres.dart';
import '../auth/login.dart';
class EcranMonProfil extends StatefulWidget {
  const EcranMonProfil({super.key});

  @override
  State<EcranMonProfil> createState() => _EcranMonProfilState();
}

class _EcranMonProfilState extends State<EcranMonProfil> {
  String _nomPrenom = "";
  String _email = "";
  int _incidentsResolusCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<void> _chargerProfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await ApiService.getUserProfile(token as String);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          final firstName = data['first_name']?.toString() ?? "";
          final lastName = data['last_name']?.toString() ?? "";

          _nomPrenom = "$firstName $lastName".trim();

          if (_nomPrenom.isEmpty) {
            _nomPrenom = "Utilisateur FixCity";
          }

          _email = data['email']?.toString() ?? "";

          _incidentsResolusCount =
              int.tryParse(data['signalements_resolus'].toString()) ?? 0;

          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // token d'acées expiré ou invalide , on tente de rafraichir le token
        final refreshToken = prefs.getString('refresh_token');
        final response = await ApiService.refreshToken(refreshToken as String);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final newAccessToken = data['access'];

          await prefs.setString('access_token', newAccessToken);

          // réessayer de charger le profil avec le nouveau token
          _chargerProfil();
        } else {
          // échec du rafraîchissement, rediriger vers la page de login
          if (!mounted) return;
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EcranLogin()),
            );
          }
        }

      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du chargement du profil.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deconnexion() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    if (!mounted) return;
    //
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CouleursApp.background,
        body: const Center(
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
                Container(
                  height: 200,
                  color: CouleursApp.primaire,
                ),
                Positioned(
                  bottom: -1,
                  left: 0,
                  right: 0,
                  child: ClipPath(
                    clipper: ArcheInverseeClipper(),
                    child: Container(
                      height: 80,
                      color: CouleursApp.background,
                    ),
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
                        Icons.person_outline_rounded,
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
                  fontSize: 13,
                  color: CouleursApp.primaire,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: CouleursApp.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CouleursApp.bordure,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "$_incidentsResolusCount",
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: CouleursApp.textPrimaire,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Incidents résolus",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: CouleursApp.textSecondaire,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 32,
                      color: CouleursApp.secondaire,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Divider(indent: 24, endIndent: 24),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Paramètres de l'application",
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
              sousTitre: "C'est quoi FixCity, conditions et contact",
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CouleursApp.textPrimaire,
          ),
        ),
        subtitle: sousTitre.isNotEmpty
            ? Text(
                sousTitre,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              )
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