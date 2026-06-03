import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/couleurs_app.dart';
import '../../services/api_service.dart';
import '../auth/login.dart';
class Signalement {
  final String id;
  final String type;
  final List<String> images;
  final String statut;
  final String description;
  final String dateCreation;

  Signalement({
    required this.id,
    required this.type,
    required this.images,
    required this.statut,
    required this.description,
    required this.dateCreation,
  });

  factory Signalement.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['url_image']?.toString() ?? '';

    return Signalement(
      id: json['id'].toString(),
      type: json['categorie']?.toString() ?? 'Type inconnu',
      images: imageUrl.isNotEmpty ? [imageUrl] : [],
      statut: _normaliserStatut(json['statut']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      dateCreation: json['date_signalement']?.toString() ?? '',
    );
  }

  static String _normaliserStatut(String statutBackend) {
    final statut = statutBackend.toUpperCase();

    if (statut == 'NOUVEAU' || statut == 'ENVOYE' || statut == 'ENVOYÉ') {
      return 'Envoyé';
    }

    if (statut == 'EN_COURS' || statut.contains('COURS')) {
      return 'En cours';
    }

    if (statut == 'RESOLU' || statut == 'RÉSOLU') {
      return 'Résolu';
    }

    return statutBackend;
  }
}

class EcranMesSignalements extends StatefulWidget {
  const EcranMesSignalements({super.key});

  @override
  State<EcranMesSignalements> createState() => _EcranMesSignalementsState();
}

class _EcranMesSignalementsState extends State<EcranMesSignalements> {
  String _filtreActif = 'Tous';

  bool _isLoading = true;
  String? _messageErreur;

  List<Signalement> _tousLesSignalements = [];

  @override
  void initState() {
    super.initState();
    _chargerSignalements();
  }

  Future<void> _chargerSignalements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await ApiService.listeIncidents(token as String);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          setState(() {
            _tousLesSignalements = data
                .map((item) => Signalement.fromJson(item))
                .toList();

            _isLoading = false;
            _messageErreur = null;
          });
        } else {
          setState(() {
            _isLoading = false;
            _messageErreur = 'Format de données invalide.';
          });
        }
      } else if (response.statusCode == 401) {
        //token d'accès expiré ou invalide, on tente de le rafraîchir
        final refreshToken = prefs.getString('refresh_token');
        final response= await ApiService.refreshToken(refreshToken!);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final newAccess = data['access'];

          // Stocker le nouveau token d'accès
          await prefs.setString('access_token', newAccess);

          // Réessayer de charger les signalements avec le nouveau token
          _chargerSignalements();
        } else {
          // Le rafraîchissement a échoué, rediriger vers la page de connexion
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EcranLogin()),
            );
          }
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
      case 'envoyé':
        return Colors.orange;
      case 'en cours':
        return CouleursApp.encours;
      case 'résolu':
        return CouleursApp.resolu;
      default:
        return CouleursApp.textSecondaire;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Signalement> signalementsFiltres =
        _tousLesSignalements.where((s) {
      if (_filtreActif == 'Tous') return true;
      return s.statut.toLowerCase() == _filtreActif.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: CouleursApp.background,
      appBar: AppBar(
        backgroundColor: CouleursApp.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Mes signalements",
          style: TextStyle(
            color: CouleursApp.textPrimaire,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: CouleursApp.primaire,
                ),
              )
            : _messageErreur != null
                ? _buildErreur()
                : Column(
                    children: [
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: Row(
                            children: [
                              _buildBoutonFiltre(
                                "Tous",
                                CouleursApp.textPrimaire,
                              ),
                              _buildBoutonFiltre(
                                "Envoyé",
                                Colors.orange,
                              ),
                              _buildBoutonFiltre(
                                "En cours",
                                CouleursApp.encours,
                              ),
                              _buildBoutonFiltre(
                                "Résolu",
                                CouleursApp.resolu,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: RefreshIndicator(
                          color: CouleursApp.primaire,
                          onRefresh: _chargerSignalements,
                          child: signalementsFiltres.isEmpty
                              ? _buildEcranVide()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  itemCount: signalementsFiltres.length,
                                  itemBuilder: (context, index) {
                                    return _buildCarteSignalement(
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
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              _messageErreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: CouleursApp.textSecondaire,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _messageErreur = null;
                });
                _chargerSignalements();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursApp.primaire,
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
          color: estSelectionne ? CouleursApp.card : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: estSelectionne
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
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
                fontWeight:
                    estSelectionne ? FontWeight.bold : FontWeight.w500,
                color: estSelectionne
                    ? CouleursApp.textPrimaire
                    : CouleursApp.textSecondaire,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarteSignalement(Signalement signalement) {
    final Color couleurStatut = _obtenirCouleurStatut(signalement.statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: CouleursApp.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CouleursApp.bordure, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Type d'incident",
                  style: TextStyle(
                    fontSize: 12,
                    color: CouleursApp.textSecondaire,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signalement.type,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: CouleursApp.textPrimaire,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 180,
            width: double.infinity,
            child: signalement.images.isEmpty
                ? Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 45,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : PageView.builder(
                    itemCount: signalement.images.length,
                    itemBuilder: (context, i) {
                      return Image.network(
                        signalement.images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 45,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Statut",
                  style: TextStyle(
                    fontSize: 12,
                    color: CouleursApp.textSecondaire,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: couleurStatut,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      signalement.statut,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CouleursApp.textPrimaire,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "Description",
                  style: TextStyle(
                    fontSize: 12,
                    color: CouleursApp.textSecondaire,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signalement.description.isEmpty
                      ? "Aucune description."
                      : signalement.description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: CouleursApp.textPrimaire,
                    height: 1.3,
                  ),
                ),
                if (signalement.dateCreation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    signalement.dateCreation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CouleursApp.textSecondaire,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                  Icons.assignment_turned_in_outlined,
                  size: 60,
                  color: CouleursApp.grisHint,
                ),
                const SizedBox(height: 10),
                Text(
                  "Aucun signalement",
                  style: const TextStyle(
                    color: CouleursApp.textSecondaire,
                    fontSize: 15,
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