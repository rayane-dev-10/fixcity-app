import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/couleurs_app.dart';
import '../../services/api_service.dart';
import 'signin.dart';
import '../auth/mdpoublie.dart';
import '../citoyen/accueil.dart';
import '../admin/dashboard_admin.dart';
import 'package:jwt_decoder/jwt_decoder.dart';


class EcranLogin extends StatefulWidget {
  const EcranLogin({super.key});

  @override
  State<EcranLogin> createState() => _EcranLoginState();
}

class _EcranLoginState extends State<EcranLogin> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _motDePasseCache = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validerEmailLogin(String? value) {
    final email = value?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      return 'Email requis';
    }

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');

    if (!emailRegex.hasMatch(email)) {
      return 'Email invalide';
    }

    if (!email.endsWith('@gmail.com') && !email.endsWith('@fixcity.dz')) {
      return 'Email doit se terminer par @gmail.com ou @fixcity.dz';
    }

    return null;
  }

  String? _validerMotDePasse(String? value) {
  final password = value ?? '';

  if (password.isEmpty) {
    return 'Mot de passe requis';
  }

  final valide = password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'\d').hasMatch(password) &&
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=;\/\\\[\]]')
          .hasMatch(password);

  if (!valide) {
    return 'Le mot de passe doit contenir au moins 8 caractères, une lettre majuscule, une lettre minuscule, un caractère spécial et un chiffre';
  }

  return null;
}

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();

      final response = await ApiService.login(
        email,
        _passwordController.text.trim(),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
final String access = data['access'];
final String refresh = data['refresh'];

final prefs = await SharedPreferences.getInstance();
await prefs.setString('access_token', access);
await prefs.setString('refresh_token', refresh);

final decodedToken = JwtDecoder.decode(access);

final bool isCitoyen = decodedToken['is_citoyen'] == true;
final bool isAgent = decodedToken['is_agent'] == true;

if (!mounted) return;

if (isAgent) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const DashboardAdmin(),
    ),
  );
} else if (isCitoyen) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const EcranAccueil(),
    ),
  );
} else {
  _afficherErreur('Rôle utilisateur non reconnu.');
}
      } else {
        _afficherErreur(data['detail'] ?? 'Email ou mot de passe incorrect');
      }
    } catch (_) {
      if (!mounted) return;
      _afficherErreur('Problème de connexion au serveur.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  InputDecoration _buildSimpleInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD7D7D7), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CouleursApp.primaire, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursApp.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Form(
              key: _formKey,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: CouleursApp.primaire,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          cursorColor: CouleursApp.primaire,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildSimpleInputDecoration('Votre email'),
                          validator: _validerEmailLogin,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Mot de passe',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          cursorColor: CouleursApp.primaire,
                          obscureText: _motDePasseCache,
                          decoration: _buildSimpleInputDecoration(
                            'Votre mot de passe',
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _motDePasseCache
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _motDePasseCache = !_motDePasseCache;
                                });
                              },
                            ),
                          ),
                          validator: _validerMotDePasse,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EcranMotDePasseOublie(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: CouleursApp.primaire,
                          ),
                          child: const Text('Mot de passe oublié ?'),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CouleursApp.primaire,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  CouleursApp.primaire.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Se connecter'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EcranSignIn(),
                                ),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "Vous n’avez pas de compte ? ",
                                  ),
                                  TextSpan(
                                    text: "Inscrivez-vous",
                                    style: TextStyle(
                                      color: CouleursApp.primaire,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -30,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: CouleursApp.primaire,
                              child: const Center(
                                child: Text(
                                  'FC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}