import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../auth/login.dart';
import '../citoyen/accueil.dart';
import '../admin/dashboard_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class EcranSplash extends StatefulWidget {
  const EcranSplash({super.key});

  @override
  State<EcranSplash> createState() => _EcranSplashState();
}

class _EcranSplashState extends State<EcranSplash> {
  late VideoPlayerController _controller;
  bool _estInitialise = false;
  bool _aNavigue = false; // Empêche le déclenchement multiple de la navigation

  @override
  void initState() {
    super.initState();
    _preparerVideo();
  }

  Future<void> _preparerVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/splashscreen.mp4');

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _estInitialise = true;
        });
        await _controller.setVolume(0.0);
        await _controller.play();
        
        _controller.addListener(() {
          if (_controller.value.position >= _controller.value.duration && !_aNavigue) {
            _aNavigue = true;
            _verifierSessionEtNaviguer();
          }
        });
      }
    } catch (erreur) {
      print("Erreur de décodage de la vidéo : $erreur");
      if (!_aNavigue) {
        _aNavigue = true;
        Future.delayed(const Duration(seconds: 2), _allerVersLogin);
      }
    }
  }

  // Fonction principale de vérification de session
  Future<void> _verifierSessionEtNaviguer() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');

    // 1. La paire de tokens n'est pas stockée
    if (accessToken == null || refreshToken == null) {
      _allerVersLogin();
      return;
    }

    // 2. Vérifier si le refresh token est expiré
    bool isRefreshExpired = JwtDecoder.isExpired(refreshToken);
    if (isRefreshExpired) {
      // Refresh token expiré -> Login
      await prefs.clear(); // Optionnel: nettoyer les vieux tokens
      _allerVersLogin();
      return;
    }

    // 3. Vérifier l'access token
    bool isAccessExpired = JwtDecoder.isExpired(accessToken);
    String tokenValide = accessToken;
    
    if (isAccessExpired) {
      // AJOUT : Try/Catch pour protéger contre les pannes réseau
      try {
        final response = await ApiService.refreshToken(refreshToken);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          tokenValide = data['access'];
          await prefs.setString('access_token', tokenValide);
        } else {
          _allerVersLogin();
          return;
        }
      } catch (e) {
        print("Erreur réseau ou API lors du rafraîchissement: $e");
        // En cas de panne internet, on le renvoie au login (ou on pourrait lui afficher un message)
        _allerVersLogin();
        return;
      }
    }

    // 4. Les tokens sont valides, on décode le payload pour le rôle
    Map<String, dynamic> payload = JwtDecoder.decode(tokenValide);

    if (mounted) {
      if (payload['is_citoyen'] == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EcranAccueil()));
      } else if (payload['is_agent'] == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardAdmin()));
      }
    }
  }



  // Redirection classique vers le Login
  void _allerVersLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EcranLogin()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _estInitialise
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00964F)),
              ),
      ),
    );
  }
}