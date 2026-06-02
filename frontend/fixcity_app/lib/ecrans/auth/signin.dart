import 'dart:convert';
import 'package:flutter/material.dart';

import '../../utils/couleurs_app.dart';
import '../../services/api_service.dart';
import 'ecran_verification_otp.dart';

class EcranSignIn extends StatefulWidget {
  const EcranSignIn({super.key});

  @override
  State<EcranSignIn> createState() => _EcranSignInState();
}

class _EcranSignInState extends State<EcranSignIn> {
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _mdpController = TextEditingController();
  final _confirmeMdpController = TextEditingController();

  bool _isLoading = false;
  bool _obscureMdp = true;
  bool _obscureConfirme = true;

  String? _validerTexteSimple(String? value, String champ) {
    if (value == null || value.trim().isEmpty) {
      return '$champ requis';
    }

    if (value.trim().length < 2) {
      return '$champ trop court';
    }

    return null;
  }

  String? _validerEmailCitoyen(String? value) {
    final email = value?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      return 'Email requis';
    }

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');

    if (!emailRegex.hasMatch(email)) {
      return 'Email invalide';
    }

    if (!email.endsWith('@gmail.com')) {
      return 'Utilisez un email Gmail pour créer un compte citoyen';
    }

    return null;
  }

  String? _validerMotDePasse(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Mot de passe requis';
    }

    if (password.length < 8) {
      return 'Minimum 8 caractères';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Le mot de passe doit contenir une majuscule';
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Le mot de passe doit contenir un chiffre';
    }

    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=;\/\\\[\]]').hasMatch(password)) {
      return 'Le mot de passe doit contenir un symbole';
    }

    return null;
  }

  String _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
      if (data is Map && data.containsKey('email')) {
        return data['email'].toString();
      }
      return data.toString();
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  Future<void> _envoyerOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();

    final Map<String, dynamic> userData = {
      'first_name': _prenomController.text.trim(),
      'last_name': _nomController.text.trim(),
      'email': email,
      'password': _mdpController.text.trim(),
    };

    try {
      final response = await ApiService.sendRegisterOtp(email);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code OTP envoyé. Vérifiez votre email.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EcranVerificationOtp(
              email: email,
              userData: userData,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_extractErrorMessage(response.body)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur de connexion au serveur.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _mdpController.dispose();
    _confirmeMdpController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      suffixIcon: suffixIcon,
      errorMaxLines: 2,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CouleursApp.grisBordure),
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

  Widget _label(String text, {bool obligatoire = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          color: CouleursApp.textPrimaire,
        ),
        children: [
          TextSpan(text: text),
          if (obligatoire)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _champTexte({
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      cursorColor: CouleursApp.primaire,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(),
    );
  }

  Widget _champMotDePasse({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      cursorColor: CouleursApp.primaire,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
            size: 22,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursApp.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
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
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Nom', obligatoire: true),
                                  const SizedBox(height: 8),
                                  _champTexte(
                                    controller: _nomController,
                                    validator: (v) =>
                                        _validerTexteSimple(v, 'Nom'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Prénom', obligatoire: true),
                                  const SizedBox(height: 8),
                                  _champTexte(
                                    controller: _prenomController,
                                    validator: (v) =>
                                        _validerTexteSimple(v, 'Prénom'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _label('Email', obligatoire: true),
                        const SizedBox(height: 8),
                        _champTexte(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validerEmailCitoyen,
                        ),

                        const SizedBox(height: 20),
                        _label('Créez un mot de passe', obligatoire: true),
                        const SizedBox(height: 8),
                        _champMotDePasse(
                          controller: _mdpController,
                          obscure: _obscureMdp,
                          validator: _validerMotDePasse,
                          onToggle: () {
                            setState(() {
                              _obscureMdp = !_obscureMdp;
                            });
                          },
                        ),

                        const SizedBox(height: 20),
                        _label('Confirmez votre mot de passe',
                            obligatoire: true),
                        const SizedBox(height: 8),
                        _champMotDePasse(
                          controller: _confirmeMdpController,
                          obscure: _obscureConfirme,
                          validator: (v) {
                            final error = _validerMotDePasse(v);
                            if (error != null) return error;

                            if (v != _mdpController.text) {
                              return 'Les deux mots de passe doivent être identiques';
                            }

                            return null;
                          },
                          onToggle: () {
                            setState(() {
                              _obscureConfirme = !_obscureConfirme;
                            });
                          },
                        ),

                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _envoyerOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CouleursApp.primaire,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  CouleursApp.primaire.withOpacity(0.5),
                              elevation: 0,
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
                                : const Text(
                                    'S’inscrire',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                children: [
                                  TextSpan(text: 'Vous avez déjà un compte ? '),
                                  TextSpan(
                                    text: 'Connectez-vous',
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
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
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