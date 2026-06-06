import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/couleurs_app.dart';
import '../../services/api_service.dart';

class EcranMotDePasseOublie extends StatefulWidget {
  const EcranMotDePasseOublie({super.key});

  @override
  State<EcranMotDePasseOublie> createState() => _EcranMotDePasseOublieState();
}

class _EcranMotDePasseOublieState extends State<EcranMotDePasseOublie> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  bool _nouveauMpOculte = true;
  bool _confMpOculte = true;

  int _etape = 0;
  // 0 = email
  // 1 = otp
  // 2 = nouveau mot de passe

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _messageErreur(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (data is Map && data['email'] != null) return data['email'].toString();
      if (data is Map && data['otp'] != null) return data['otp'].toString();
      if (data is Map && data['password'] != null) return data['password'].toString();

      return data.toString();
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

String? _validerMotDePasseFort(String? valeur) {
  final password = valeur ?? '';

  if (password.isEmpty) {
    return 'Mot de passe requis';
  }

  if (password.length < 8) {
    return 'Doit contenir au moins 8 caractères';
  }

  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Doit contenir une lettre majuscule';
  }

  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Doit contenir une lettre minuscule';
  }

  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Doit contenir un chiffre';
  }

  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=;\/\\\[\]]')
      .hasMatch(password)) {
    return 'Doit contenir un caractère spécial';
  }

  return null;
}

  void _showErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _actionPrincipale() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      if (_etape == 0) {
        final response = await ApiService.passwordResetSendOtp(email);

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() => _etape = 1);
          _showSucces('Code OTP envoyé. Vérifiez votre email.');
        } else {
          _showErreur(_messageErreur(response.body));
        }
      } else if (_etape == 1) {
        final response = await ApiService.passwordResetVerify(
          email,
          _codeController.text.trim(),
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() => _etape = 2);
          _showSucces('Code validé.');
        } else {
          _showErreur(_messageErreur(response.body));
        }
      } else {
        final response = await ApiService.passwordResetConfirm(
          email,
          _passwordController.text.trim(),
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _dialogueSuccesFinal();

          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          _showErreur(_messageErreur(response.body));
        }
      }
    } catch (_) {
      if (!mounted) return;
      _showErreur('Erreur de connexion au serveur.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _renvoyerCode() async {
    setState(() => _isResending = true);

    try {
      final response = await ApiService.passwordResetSendOtp(
        _emailController.text.trim(),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSucces('Nouveau code OTP envoyé.');
      } else {
        _showErreur(_messageErreur(response.body));
      }
    } catch (_) {
      if (!mounted) return;
      _showErreur('Erreur de connexion au serveur.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  String get _titre {
    if (_etape == 0) return 'Mot de passe oublié ?';
    if (_etape == 1) return 'Entrez le code OTP';
    return 'Nouveau mot de passe';
  }

  String get _description {
    if (_etape == 0) {
      return 'Entrez votre adresse email pour recevoir un code de vérification.';
    }

    if (_etape == 1) {
      return 'Nous avons envoyé un code à :';
    }

    return 'Définissez un nouveau mot de passe pour sécuriser votre compte.';
  }

  String get _texteBouton {
    if (_etape == 0) return 'Envoyer le code';
    if (_etape == 1) return 'Vérifier le code';
    return 'Réinitialiser';
  }

  IconData get _icone {
    if (_etape == 0) return Icons.lock_reset_outlined;
    if (_etape == 1) return Icons.mark_email_read_outlined;
    return Icons.lock_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursApp.background,
      appBar: AppBar(
        title: const Text(
          'Réinitialisation',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () {
            if (_etape > 0) {
              setState(() => _etape--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: CouleursApp.primaire,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(_etape),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIcone(),

                      const SizedBox(height: 20),

                      Text(
                        _titre,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CouleursApp.textPrimaire,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),

                      if (_etape == 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          _emailController.text.trim(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: CouleursApp.primaire,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      if (_etape == 0) _buildEmailStep(),
                      if (_etape == 1) _buildOtpStep(),
                      if (_etape == 2) _buildPasswordStep(),

                      const SizedBox(height: 24),

                      _buildBoutonPrincipal(),

                      if (_etape == 1) ...[
                        const SizedBox(height: 16),
                        _buildBoutonRenvoyer(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcone() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: CouleursApp.primaire.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        _icone,
        color: CouleursApp.primaire,
        size: 34,
      ),
    );
  }

  Widget _buildEmailStep() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      cursorColor: CouleursApp.primaire,
      style: const TextStyle(fontSize: 14),
      decoration: _decorationChamp(
        hint: 'Votre email',
        prefixIcon: Icons.email_outlined,
      ),
    validator: (valeur) {
      if (valeur == null || valeur.trim().isEmpty) {
        return 'Email requis';
      }

      final email = valeur.trim().toLowerCase();

      final emailRegex = RegExp(
        r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
      );

      if (!emailRegex.hasMatch(email)) {
        return 'Email invalide';
      }

      if (email.endsWith('@fixcity.dz')) {
        return "Veuillez contacter l'équipe FixCity pour réinitialiser votre mot de passe.";
      }

      if (!email.endsWith('@gmail.com')) {
        return 'Veuillez utiliser une adresse Gmail valide.';
      }

      return null;
    },
    );
  }

  Widget _buildOtpStep() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      cursorColor: CouleursApp.primaire,
      style: const TextStyle(
        fontSize: 22,
        letterSpacing: 8,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          letterSpacing: 8,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CouleursApp.grisBordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: CouleursApp.primaire,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
      ),
      validator: (valeur) {
        if (valeur == null || valeur.trim().isEmpty) {
          return 'Code OTP requis';
        }

        if (valeur.trim().length != 6) {
          return 'Le code doit contenir 6 chiffres';
        }

        return null;
      },
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: _nouveauMpOculte,
          cursorColor: CouleursApp.primaire,
          style: const TextStyle(fontSize: 14),
          decoration: _decorationChamp(
            hint: 'Nouveau mot de passe',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _nouveauMpOculte ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _nouveauMpOculte = !_nouveauMpOculte;
                });
              },
            ),
          ),
          validator: _validerMotDePasseFort,
        ),

        const SizedBox(height: 20),

        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _confMpOculte,
          cursorColor: CouleursApp.primaire,
          style: const TextStyle(fontSize: 14),
          decoration: _decorationChamp(
            hint: 'Confirmer le mot de passe',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _confMpOculte ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _confMpOculte = !_confMpOculte;
                });
              },
            ),
          ),
          validator: (valeur) {
            if (valeur != _passwordController.text) {
              return 'Les deux mots de passe doivent être identiques';
            }

            final erreur = _validerMotDePasseFort(valeur);
            if (erreur != null) return erreur;

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBoutonPrincipal() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _actionPrincipale,
        style: ElevatedButton.styleFrom(
          backgroundColor: CouleursApp.primaire,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CouleursApp.primaire.withOpacity(0.5),
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
            : Text(
                _texteBouton,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildBoutonRenvoyer() {
    return TextButton(
      onPressed: _isResending ? null : _renvoyerCode,
      child: _isResending
          ? const Text('Envoi en cours...')
          : Text(
              'Renvoyer le code',
              style: TextStyle(
                color: CouleursApp.primaire,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  InputDecoration _decorationChamp({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.grey,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: Colors.grey,
        size: 22,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CouleursApp.grisBordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: CouleursApp.primaire,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
      errorMaxLines: 3,
    );
  }

  Future<void> _dialogueSuccesFinal() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CouleursApp.primaire.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: CouleursApp.primaire,
                  size: 50,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Mot de passe modifié',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CouleursApp.primaire,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continuer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}