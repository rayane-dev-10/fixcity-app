import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/api_service.dart';
import 'dashboard_admin.dart';
import 'detail_signalement_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login.dart';
class SignalementAdmin {
  
  final int id;
  final String type;
  final String imageUrl;
  final String statut;
  final String description;
  final String dateCreation;
  final String citoyenEmail;
  final String adresseLisible;
  final LatLng coordonnees;

  SignalementAdmin({
    required this.id,
    required this.type,
    required this.imageUrl,
    required this.statut,
    required this.description,
    required this.dateCreation,
    required this.citoyenEmail,
    required this.adresseLisible,
    required this.coordonnees,
  });

  factory SignalementAdmin.fromJson(Map<String, dynamic> json) {
    return SignalementAdmin(
      id: int.tryParse(json['id'].toString()) ?? 0,
      type: json['categorie']?.toString() ?? 'Type inconnu',
      imageUrl: json['url_image']?.toString() ?? '',
      statut: _normaliserStatut(json['statut']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      dateCreation: json['date_signalement']?.toString() ?? '',
      citoyenEmail: json['citoyen']?.toString() ?? '',
          adresseLisible: json['adresseLisible']?.toString() ??
        json['adresse_lisible']?.toString() ??
        json['adresse']?.toString() ??
        '',
      coordonnees: LatLng(
        double.tryParse(json['lat']?.toString() ?? '') ?? 0,
        double.tryParse(json['long']?.toString() ?? '') ?? 0,
      ),
    );
  }

  static String _normaliserStatut(String statutBackend) {
    final statut = statutBackend.toUpperCase();

    if (statut == 'NOUVEAU') return 'Pas traité';
    if (statut == 'EN_COURS' || statut.contains('COURS')) return 'En cours';
    if (statut == 'RESOLU' || statut == 'RÉSOLU') return 'Résolu';

    return statutBackend;
  }
}

class EcranListeSignalementsAdmin extends StatefulWidget {
  const EcranListeSignalementsAdmin({super.key});

  @override
  State<EcranListeSignalementsAdmin> createState() =>
      _EcranListeSignalementsAdminState();
}

class _EcranListeSignalementsAdminState
    extends State<EcranListeSignalementsAdmin> {
  String _filtreActif = 'Tous';

  bool _isLoading = true;
  String? _messageErreur;

  List<SignalementAdmin> _tousLesSignalements = [];

  @override
  void initState() {
    super.initState();
    _chargerSignalementsService();
  }

  Future<void> _chargerSignalementsService() async {
    setState(() {
      _isLoading = true;
      _messageErreur = null;
    });

    try{
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      final response = await ApiService.listeIncidentsService(accessToken as String);
       
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          final incidents = data
              .whereType<Map<String, dynamic>>()
              .map((item) => SignalementAdmin.fromJson(item))
              .toList();

          setState(() {
            _tousLesSignalements = incidents;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _messageErreur = 'Format de données invalide.';
          });
        }
      } else if (response.statusCode == 401) {
        // token d'accès expiré ou invalide, on essaye de le rafraîchir
        final nouveauAccessToken = await ApiService.refreshToken(refreshToken as String);
        if (nouveauAccessToken.statusCode == 200) {
          final data = jsonDecode(nouveauAccessToken.body);
          final tokenValide = data['access'];
          await prefs.setString('access_token', tokenValide);

          // Réessayer de charger les signalements avec le nouveau token
          await _chargerSignalementsService();
        } else {
          // rafraîchissement échoué, on redirige vers le login
          await prefs.clear();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EcranLogin()),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _messageErreur = 'Erreur de connexion au serveur.';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final signalementsFiltres = _tousLesSignalements.where((s) {
      if (_filtreActif == 'Tous') return true;
      return s.statut.toLowerCase() == _filtreActif.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Gestion des Signalements",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00964F),
                ),
              )
            : _messageErreur != null
                ? _buildErreur()
                : Column(
                    children: [
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEFEF),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: Row(
                            children: [
                              _buildBoutonFiltre("Tous", Colors.black54),
                              _buildBoutonFiltre("Pas traité", Colors.red),
                              _buildBoutonFiltre(
                                "En cours",
                                const Color.fromARGB(255, 224, 213, 0),
                              ),
                              _buildBoutonFiltre(
                                "Résolu",
                                const Color(0xFF34C759),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFF00964F),
                          onRefresh: _chargerSignalementsService,
                          child: signalementsFiltres.isEmpty
                              ? _buildEcranVide()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  itemCount: signalementsFiltres.length,
                                  itemBuilder: (context, index) {
                                    return _buildCarteSignalementAdmin(
                                      signalementsFiltres[index],
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 55),
            const SizedBox(height: 12),
            Text(
              _messageErreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _chargerSignalementsService,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00964F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutonFiltre(String label, Color couleurPastille) {
    final bool estSelectionne = _filtreActif == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filtreActif = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: estSelectionne ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: estSelectionne
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: couleurPastille,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: estSelectionne ? FontWeight.bold : FontWeight.w500,
                color: estSelectionne ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarteSignalementAdmin(SignalementAdmin signalement) {
    final couleurStatut = _obtenirCouleurStatut(signalement.statut);

    return GestureDetector(
      onTap: () async {
        final resultat = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EcranDetailSignalementAdmin(
              incident: IncidentCommunaute(
                id: signalement.id.toString(),
                type: signalement.type,
                statut: signalement.statut,
                descriptionCourte: signalement.description,
                coordonnees: signalement.coordonnees,
                adresseLisible: signalement.adresseLisible,
              ),
              imageUrl: signalement.imageUrl,
              dateSignalement: signalement.dateCreation,
              citoyenEmail: signalement.citoyenEmail,
              adresseLisible: signalement.adresseLisible,
            ),
          ),
        );

        if (resultat == true) {
          await _chargerSignalementsService();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEFEFEF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Identifiant Ticket",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "#${signalement.id}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: couleurStatut.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      signalement.statut,
                      style: TextStyle(
                        color: couleurStatut,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: signalement.imageUrl.isEmpty
                  ? Container(
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      ),
                    )
                  : Image.network(
                      signalement.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Catégorie de l'incident",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signalement.type,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Description remontée",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    signalement.description.isEmpty
                        ? "Aucune description."
                        : signalement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEcranVide() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 55,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  "Aucun incident dans la catégorie '$_filtreActif'",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}