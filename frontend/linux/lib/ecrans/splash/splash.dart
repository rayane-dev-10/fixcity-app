import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../auth/login.dart';

class EcranSplash extends StatefulWidget {
  const EcranSplash({super.key});

  @override
  State<EcranSplash> createState() => _EcranSplashState();
}

class _EcranSplashState extends State<EcranSplash> {
  late VideoPlayerController _controller;
  bool _estInitialise = false;

  @override
  void initState() {
    super.initState();
    _preparerVideo();
  }

  Future<void> _preparerVideo() async {
    // Initialisation native directe depuis les assets
    _controller = VideoPlayerController.asset('assets/videos/splashscreen.mp4');

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _estInitialise = true;
        });
        await _controller.setVolume(0.0); // Coupe le son (évite les blocages de sécurité Android)
        await _controller.play();
        
        // Écouteur pour intercepter la fin de la vidéo
        _controller.addListener(() {
          if (_controller.value.position >= _controller.value.duration) {
            _naviguerVersLogin();
          }
        });
      }
    } catch (erreur) {
      print("Erreur de décodage de la vidéo : $erreur");
      // Sécurité : Si le lecteur Android refuse le codec, on force quand même l'accès au Login après 2 secondes
      Future.delayed(const Duration(seconds: 2), _naviguerVersLogin);
    }
  }

  void _naviguerVersLogin() {
    if (mounted) {
      // Supprime le Splash de la pile de navigation et ouvre le Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EcranLogin()), // <-- Met le nom exact de ta classe de Login ici
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Libère la mémoire
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fond blanc assorti au reste
      body: Center(
        child: _estInitialise
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover, // Plein écran sans déformation
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00964F)),
              ), // Loader vert pendant le micro-chargement initial
      ),
    );
  }
}