import 'package:flutter/material.dart';
import 'utils/couleurs_app.dart';
// CORRIGÉ : On passe en import absolu avec le nom de ton package pour que Flutter trouve le fichier à coup sûr
import 'package:fixcity_app/ecrans/splash/splash.dart'; 

void main() {
  runApp(const FixCityApp());
}

class FixCityApp extends StatelessWidget {
  const FixCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FixCity',
      theme: ThemeData(
        scaffoldBackgroundColor: CouleursApp.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CouleursApp.primaire,
        ),
        useMaterial3: true,
      ),
      // Toujours sans le mot-clé const !
      home: EcranSplash(), 
    );
  }
}