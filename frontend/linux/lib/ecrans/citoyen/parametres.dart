import 'package:flutter/material.dart';
import '../../utils/couleurs_app.dart';

class EcranParametres extends StatelessWidget {
  const EcranParametres({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursApp.background,
      appBar: AppBar(
        backgroundColor: CouleursApp.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Paramètres",
          style: TextStyle(
            color: CouleursApp.textPrimaire, 
            fontSize: 22, 
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Padding vertical augmenté à 16 pour décoller proprement le bloc du haut
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CouleursApp.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CouleursApp.bordure, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04), 
                  blurRadius: 10, 
                  offset: const Offset(0, 4)
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- EN-TÊTE DU BLOC ---
                Text(
                  "À propos de FixCity",
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: CouleursApp.textPrimaire
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 1.5,
                  width: double.infinity,
                  color: CouleursApp.primaire, // Ligne verte sous le titre
                ),
                const SizedBox(height: 24),

                // --- SECTION 1 : C'EST QUOI FIXCITY ? (Avec icône info classique) ---
                _buildSectionTextuelle(
                  icone: Icons.info_outline_rounded,
                  titre: "C’est quoi FixCity ?",
                  texte: "FixCity est une application mobile qui permet aux citoyens de signaler facilement les problèmes urbains tels que les déchets, les routes endommagées ou les coupures d’eau et d’électricité.\n\nLes signalements sont transmis aux autorités compétentes afin d’assurer un meilleur suivi et une amélioration du cadre de vie.",
                ),

                const SizedBox(height: 24),

                // --- SECTION 2 : CONDITIONS D'UTILISATION ---
                _buildSectionTextuelle(
                  icone: Icons.description_outlined,
                  titre: "Conditions d’utilisation",
                  texte: "- Les signalements doivent être réels et non abusifs.\n- L’application ne garantit pas une résolution immédiate des incidents.\n- Les données de localisation sont utilisées uniquement pour traiter les signalements.",
                ),

                const SizedBox(height: 24),

                // --- SECTION 3 : CONTACT ---
                _buildSectionTextuelle(
                  icone: Icons.chat_bubble_outline,
                  titre: "Contact",
                  texte: "Email : fixcity@gmail.com\nWeb :",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- COMPOSANT : AFFICHAGE DU TEXTE ET DE SON ICÔNE ---
  Widget _buildSectionTextuelle({
    required IconData icone, 
    required String titre, 
    required String texte
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône alignée en haut à gauche du texte
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(icone, color: Colors.black87, size: 22),
        ),
        const SizedBox(width: 14),
        
        // Bloc d'informations textuelles (Titre + Description)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.bold, 
                  color: CouleursApp.textPrimaire
                ),
              ),
              const SizedBox(height: 6),
              Text(
                texte,
                style: TextStyle(
                  fontSize: 13.5, 
                  height: 1.4, 
                  color: CouleursApp.textSecondaire
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}