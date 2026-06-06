import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../utils/couleurs_app.dart';
import 'detail_signalement_admin.dart';
import 'liste_signalements.dart';
import 'profil_admin.dart';
import '../auth/login.dart';
class IncidentCommunaute {
  final String id;
  final String type;
  String statut;
  final String descriptionCourte;
  final LatLng coordonnees;
  final String imageUrl;
  final String dateSignalement;
  final String citoyenEmail;
  final String adresseLisible;

  IncidentCommunaute({
    required this.id,
    required this.type,
    required this.statut,
    required this.descriptionCourte,
    required this.coordonnees,
    this.imageUrl = '',
    this.dateSignalement = '',
    this.citoyenEmail = '',
    this.adresseLisible = '',
  });
}

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  int _indexSelectionne = 0;
  int _refreshListeKey = 0;
  int _refreshProfilKey = 0;

  bool _isLoading = true;
  String? _messageErreur;

  final MapController _mapController = MapController();
  final PopupController _popupLayerController = PopupController();

  LatLng _centreCommune = LatLng(36.7118, 4.0459);

  IncidentCommunaute? _incidentSelectionne;

  List<IncidentCommunaute> _signalementsAValider = [];

  @override
  void initState() {
    super.initState();
    _chargerIncidentsService();
  }

  @override
  void dispose() {
    _popupLayerController.dispose();
    super.dispose();
  }

  String _normaliserStatut(String statutBackend) {
    final statut = statutBackend.toUpperCase();

    if (statut == 'NOUVEAU') return 'Pas traité';
    if (statut.contains('COURS')) return 'En cours';
    if (statut == 'RESOLU' || statut == 'RÉSOLU') return 'Résolu';

    return statutBackend;
  }

  Future<void> _chargerIncidentsService() async {
    setState(() {
      _isLoading = true;
      _messageErreur = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_centreCommune, 14.5);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      final response = await ApiService.listeIncidentsService(accessToken as String);

      if (!mounted) return;

      if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            if (data is List) {
              double? latitudeSiege;
              double? longitudeSiege;

              if (data.length >= 2) {
                latitudeSiege = double.tryParse(data[data.length - 2].toString());
                longitudeSiege = double.tryParse(data[data.length - 1].toString());
              }

              final incidentsData = data.whereType<Map<String, dynamic>>().toList();

              setState(() {
                if (latitudeSiege != null && longitudeSiege != null) {
                  _centreCommune = LatLng(latitudeSiege, longitudeSiege);
                }

                _signalementsAValider = incidentsData.map((item) {
                  return IncidentCommunaute(
                    id: item['id'].toString(),
                    type: item['categorie']?.toString() ?? 'Inconnu',
                    statut: _normaliserStatut(item['statut']?.toString() ?? ''),
                    descriptionCourte: item['description']?.toString() ?? '',
                    coordonnees: LatLng(
                      double.tryParse(item['lat']?.toString() ?? '') ?? 0,
                      double.tryParse(item['long']?.toString() ?? '') ?? 0,
                    ),
                    imageUrl: item['url_image']?.toString() ?? '',
                    dateSignalement:
                        item['date_signalement']?.toString() ?? '',
                    citoyenEmail: item['citoyen']?.toString() ?? '',
                    adresseLisible: item['adresseLisible']?.toString() ??
                        item['adresse_lisible']?.toString() ??
                        item['adresse']?.toString() ??
                        '',
                  );
                })
                .where(
                  (incident) =>
                      incident.coordonnees.latitude != 0 &&
                      incident.coordonnees.longitude != 0,
                )
                .toList();

            _incidentSelectionne = null;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _messageErreur = "Format de données invalide";
          });
        }
      } else if (response.statusCode == 401) {
        // token d'acces expiré, on tente a le renouveler
        final response = await ApiService.refreshToken(refreshToken as String);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final nouveauAccessToken = data['access'];
          await prefs.setString('access_token', nouveauAccessToken);
          _chargerIncidentsService();
        } else if (response.statusCode == 401) { 
          //refresh token est expiré , on redirige vers login
          await prefs.clear();
          if(!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EcranLogin()),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _messageErreur = "Erreur de connexion au serveur";
      });
    }
  }

  void _rafraichirDonnees() {
    setState(() {
      _incidentSelectionne = null;
      _popupLayerController.hideAllPopups();
    });
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
    return Scaffold(
      body: IndexedStack(
        index: _indexSelectionne,
        children: [
          _buildCorpsCarteAdmin(),
          EcranListeSignalementsAdmin(
            key: ValueKey(_refreshListeKey),
          ),
          EcranProfilAdmin(
            key: ValueKey(_refreshProfilKey),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, Icons.home_filled, "Accueil"),
            _buildNavItem(
              1,
              Icons.bookmark_outline,
              Icons.bookmark,
              "Signalements",
            ),
            _buildNavItem(2, Icons.person_outline, Icons.person, "Profil"),
          ],
        ),
      ),
    );
  }

  Widget _buildCorpsCarteAdmin() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: CouleursApp.primaire,
        ),
      );
    }

    if (_messageErreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _messageErreur!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final List<Marker> marqueursSignalements = [];

    final signalementsActifs =
        _signalementsAValider.where((i) => i.statut != "Résolu").toList();

    for (final incident in signalementsActifs) {
      marqueursSignalements.add(
        Marker(
          point: incident.coordonnees,
          width: 34,
          height: 34,
          key: ValueKey('${incident.id}-${incident.statut}'),
          child: Container(
            decoration: BoxDecoration(
              color: _obtenirCouleurStatut(incident.statut),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _centreCommune,
            initialZoom: 14.0,
            onTap: (_, _) {
              _popupLayerController.hideAllPopups();
              setState(() {
                _incidentSelectionne = null;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fixcity.app',
            ),
            PopupMarkerLayer(
              options: PopupMarkerLayerOptions(
                popupController: _popupLayerController,
                markers: marqueursSignalements,
                markerTapBehavior: MarkerTapBehavior.togglePopupAndHideRest(),
                popupDisplayOptions: PopupDisplayOptions(
                  builder: (BuildContext context, Marker marker) {
                    final incident = signalementsActifs.firstWhere(
                      (i) => i.coordonnees == marker.point,
                    );

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_incidentSelectionne != incident && mounted) {
                        setState(() {
                          _incidentSelectionne = incident;
                        });
                      }
                    });

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        width: 200,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "#${incident.id} - ${incident.type}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              incident.descriptionCourte.isEmpty
                                  ? "Aucune description"
                                  : incident.descriptionCourte,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color:
                                        _obtenirCouleurStatut(incident.statut),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  incident.statut,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        Positioned(
          top: 70,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: CouleursApp.primaire,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Espace Agent",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 35,
          left: 30,
          right: 30,
          child: SizedBox(
            height: 70,
            child: ElevatedButton(
              onPressed: _incidentSelectionne == null
                  ? null
                  : () async {
                      final resultat = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EcranDetailSignalementAdmin(
                            incident: _incidentSelectionne!,
                            imageUrl: _incidentSelectionne!.imageUrl,
                            dateSignalement:
                                _incidentSelectionne!.dateSignalement,
                            citoyenEmail: _incidentSelectionne!.citoyenEmail,
                            adresseLisible:
                                _incidentSelectionne!.adresseLisible,
                          ),
                        ),
                      );

                    if (resultat == true) {
                      await _chargerIncidentsService();

                      setState(() {
                        _refreshListeKey++;
                        _refreshProfilKey++;
                        _incidentSelectionne = null;
                      });

                      _popupLayerController.hideAllPopups();
                    }

                      _rafraichirDonnees();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _incidentSelectionne == null
                    ? Colors.white.withOpacity(0.65)
                    : CouleursApp.primaire,
                disabledBackgroundColor: Colors.white.withOpacity(0.65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: _incidentSelectionne == null ? 0 : 2,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _incidentSelectionne == null
                        ? Icons.touch_app_outlined
                        : Icons.gavel_rounded,
                    color: _incidentSelectionne == null
                        ? Colors.black87
                        : Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _incidentSelectionne == null
                        ? "Sélectionnez un signalement"
                        : "Traiter le signalement #${_incidentSelectionne!.id}",
                    style: TextStyle(
                      color: _incidentSelectionne == null
                          ? Colors.black87
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconeNormal,
    IconData iconeActif,
    String label,
  ) {
    final bool estSelectionne = _indexSelectionne == index;

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() {
            _indexSelectionne = index;
          });

          if (index == 0) {
            await _chargerIncidentsService();
          }

          if (index == 2) {
            setState(() {
              _refreshProfilKey++;
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color:
                estSelectionne ? const Color(0xFF006D41) : Colors.transparent,
            borderRadius: estSelectionne
                ? const BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                estSelectionne ? iconeActif : iconeNormal,
                color: estSelectionne
                    ? Colors.white
                    : const Color(0xFF00964F),
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: estSelectionne
                      ? Colors.white
                      : const Color(0xFF00964F),
                  fontSize: 11,
                  fontWeight:
                      estSelectionne ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}