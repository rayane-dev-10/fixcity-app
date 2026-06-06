import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../utils/couleurs_app.dart';

class EcranDetailSignalementCitoyen extends StatelessWidget {
  final String id;
  final String type;
  final String statut;
  final String description;
  final LatLng coordonnees;
  final String imageUrl;
  final String dateSignalement;
  final String citoyenEmail;
  final String adresseLisible;

  const EcranDetailSignalementCitoyen({
    super.key,
    required this.id,
    required this.type,
    required this.statut,
    required this.description,
    required this.coordonnees,
    this.imageUrl = '',
    this.dateSignalement = '',
    this.citoyenEmail = '',
    this.adresseLisible = '',
  });

  Color _obtenirCouleurStatut(String statut) {
    switch (statut.toLowerCase()) {
      case 'envoyé':
      case 'pas traité':
      case 'nouveau':
        return Colors.orange;
      case 'en cours':
        return const Color.fromARGB(255, 224, 213, 0);
      case 'résolu':
        return const Color(0xFF34C759);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleurStatut = _obtenirCouleurStatut(statut);
    final identifiant = id.replaceAll('#', '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Signalement #$identifiant",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: couleurStatut.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: couleurStatut,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statut.isEmpty ? "Statut inconnu" : statut,
                        style: TextStyle(
                          color: couleurStatut,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    adresseLisible.isEmpty
                        ? "Position du signalement"
                        : adresseLisible,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              type,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),

            const SizedBox(height: 18),

            _buildInfoBloc(
              titre: "Email du citoyen",
              contenu: citoyenEmail.isEmpty
                  ? "Email non disponible"
                  : citoyenEmail,
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 12),

            _buildInfoBloc(
              titre: "Date du signalement",
              contenu: dateSignalement.isEmpty
                  ? "Date non disponible"
                  : dateSignalement,
              icon: Icons.calendar_today_outlined,
            ),

            const SizedBox(height: 12),

            _buildInfoBloc(
              titre: "Adresse",
              contenu: adresseLisible.isEmpty
                  ? "Adresse non disponible"
                  : adresseLisible,
              icon: Icons.place_outlined,
            ),

            const SizedBox(height: 18),

            const Text(
              "Description du problème :",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEFEFEF)),
              ),
              child: Text(
                description.isEmpty ? "Aucune description." : description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),



          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                "Photo non disponible",
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: double.infinity,
            height: 220,
            color: Colors.grey[200],
            child: const Icon(
              Icons.broken_image_outlined,
              size: 55,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBloc({
    required String titre,
    required String contenu,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CouleursApp.primaire),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contenu,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
