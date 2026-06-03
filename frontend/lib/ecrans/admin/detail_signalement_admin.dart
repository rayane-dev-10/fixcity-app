import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/couleurs_app.dart';
import 'dashboard_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';
class EcranDetailSignalementAdmin extends StatefulWidget {
  final IncidentCommunaute incident;
  final String imageUrl;
  final String dateSignalement;
  final String citoyenEmail;

  const EcranDetailSignalementAdmin({
    super.key,
    required this.incident,
    this.imageUrl = '',
    this.dateSignalement = '',
    this.citoyenEmail = '',
  });

  @override
  State<EcranDetailSignalementAdmin> createState() =>
      _EcranDetailSignalementAdminState();
}

class _EcranDetailSignalementAdminState
    extends State<EcranDetailSignalementAdmin> {
  late String _statutActuel;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _statutActuel = widget.incident.statut;
  }

  Color _obtenirCouleurStatut(String statut) {
    switch (statut.toLowerCase()) {
      case 'pas traité':
        return Colors.red;
      case 'en cours':
        return const Color.fromARGB(255, 224, 213, 0);
      case 'résolu':
        return const Color(0xFF34C759);
      default:
        return Colors.grey;
    }
  }

  Future<void> _changerStatut(String nouveauStatutApi) async {
    setState(() => _isUpdating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      final incidentId = int.tryParse(widget.incident.id.replaceAll('#', ''));

      if (incidentId == null) {
        setState(() => _isUpdating = false);
        _afficherErreur("Identifiant du signalement invalide.");
        return;
      }

      final response = await ApiService.updateStatutIncident(
        incidentId,
        nouveauStatutApi,
        accessToken as String,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _statutActuel = _normaliserStatutDepuisApi(nouveauStatutApi);
          widget.incident.statut = _statutActuel;
          _isUpdating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Statut mis à jour avec succès"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (response.statusCode == 401) {
         // token d'accès expiré, essayer de rafraîchir le token
        final response = await ApiService.refreshToken(refreshToken as String);
        if(response.statusCode != 200) {
          // rafraîchissement du token a échoué, redirection vers le login
          await prefs.clear();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          return;
        }
        final data = jsonDecode(response.body);
        final nouveauAccessToken = data['access'];
        await prefs.setString('access_token', nouveauAccessToken);
        // réessayer la mise à jour du statut avec le nouveau token
        await _changerStatut(nouveauStatutApi);   
      }
    }catch (_){
      if (!mounted) return;

      setState(() => _isUpdating = false);
      _afficherErreur("Erreur de connexion au serveur.");
    }
  }

  String _normaliserStatutDepuisApi(String statutApi) {
    if (statutApi == 'En cours de traitement') return 'En cours';
    if (statutApi == 'Résolu') return 'Résolu';
    return statutApi;
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couleurStatut = _obtenirCouleurStatut(_statutActuel);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Signalement #${widget.incident.id.replaceAll('#', '')}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                        _statutActuel,
                        style: TextStyle(
                          color: couleurStatut,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "Tizi Ouzou, Algérie",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              widget.incident.type,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),

            const SizedBox(height: 18),

            _buildInfoBloc(
              titre: "Email du citoyen",
              contenu: widget.citoyenEmail.isEmpty
                  ? "Email non disponible"
                  : widget.citoyenEmail,
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 12),

            _buildInfoBloc(
              titre: "Date du signalement",
              contenu: widget.dateSignalement.isEmpty
                  ? "Date non disponible"
                  : widget.dateSignalement,
              icon: Icons.calendar_today_outlined,
            ),

            const SizedBox(height: 12),

            _buildInfoBloc(
              titre: "Coordonnées GPS",
              contenu:
                  "${widget.incident.coordonnees.latitude.toStringAsFixed(5)}, "
                  "${widget.incident.coordonnees.longitude.toStringAsFixed(5)}",
              icon: Icons.location_on_outlined,
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
                widget.incident.descriptionCourte.isEmpty
                    ? "Aucune description."
                    : widget.incident.descriptionCourte,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 50),

            _buildBoutonAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.imageUrl.isEmpty) {
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
        widget.imageUrl,
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

  Widget _buildBoutonAction() {
    if (_isUpdating) {
      return const Center(
        child: CircularProgressIndicator(
          color: CouleursApp.primaire,
        ),
      );
    }

    if (_statutActuel == "Pas traité") {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: () => _changerStatut("En cours de traitement"),
          icon: const Icon(
            Icons.pending_actions,
            color: Colors.black87,
          ),

          label: const Text(
            "Mettre en cours de traitement",
            style: TextStyle(
              color: Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: CouleursApp.encours,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
          ),
        ),
      );
    }

    if (_statutActuel == "En cours") {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: () => _changerStatut("Résolu"),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text(
            "Marquer comme Résolu",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF34C759).withOpacity(0.3),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF34C759)),
          SizedBox(width: 10),
          Text(
            "Problème résolu",
            style: TextStyle(
              color: Color(0xFF34C759),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}