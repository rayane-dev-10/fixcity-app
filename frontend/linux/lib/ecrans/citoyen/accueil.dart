import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/api_service.dart';
import '../../utils/couleurs_app.dart';
import '../citoyen/formulaire_signalement.dart';
import '../citoyen/mon_profil.dart';
import '../citoyen/signalements.dart';

class IncidentCommunaute {
  final String id;
  final String type;
  final String statut;
  final String descriptionCourte;
  final LatLng coordonnees;

  IncidentCommunaute({
    required this.id,
    required this.type,
    required this.statut,
    required this.descriptionCourte,
    required this.coordonnees,
  });

  factory IncidentCommunaute.fromJson(Map<String, dynamic> json) {
    return IncidentCommunaute(
      id: json['id'].toString(),
      type: json['categorie']?.toString() ?? 'Type inconnu',
      statut: _normaliserStatut(json['statut']?.toString() ?? ''),
      descriptionCourte: json['description']?.toString() ?? '',
      coordonnees: LatLng(
        double.tryParse(json['lat']?.toString() ?? '') ?? 0,
        double.tryParse(json['long']?.toString() ?? '') ?? 0,
      ),
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

class PositionIncident {
  final double latitude;
  final double longitude;

  PositionIncident({
    required this.latitude,
    required this.longitude,
  });
}

class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> {
  int _indexSelectionne = 0;
  int _refreshSignalementsKey = 0;

  final MapController _mapController = MapController();
  final PopupController _popupLayerController = PopupController();

  bool _modeSelection = false;
  bool _chargementGps = false;
  bool _chargementSignalements = false;
  bool _positionChoisie = false;

  LatLng _positionActuelle = LatLng(36.7118, 4.0459);

  List<IncidentCommunaute> _signalementsVoisins = [];

  @override
  void initState() {
    super.initState();
    _chargerSignalementsCarte();
  }

  @override
  void dispose() {
    _popupLayerController.dispose();
    super.dispose();
  }

  Future<void> _chargerSignalementsCarte() async {
    setState(() => _chargementSignalements = true);

    try {
      final token = await ApiService.getValidAccessToken();

      if (token == null) {
        setState(() => _chargementSignalements = false);
        return;
      }

      final response = await ApiService.listeIncidents(token);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          setState(() {
            _signalementsVoisins = data
                .map((item) => IncidentCommunaute.fromJson(item))
                .where(
                  (incident) =>
                      incident.coordonnees.latitude != 0 &&
                      incident.coordonnees.longitude != 0,
                )
                .toList();

            _chargementSignalements = false;
          });
        } else {
          setState(() => _chargementSignalements = false);
        }
      } else {
        setState(() => _chargementSignalements = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargementSignalements = false);
    }
  }

  Color _obtenirCouleurStatut(String statut) {
    switch (statut.toLowerCase()) {
      case 'envoyé':
        return Colors.orange;
      case 'en cours':
        return const Color.fromARGB(255, 224, 213, 0);
      case 'résolu':
        return CouleursApp.resolu;
      default:
        return Colors.grey;
    }
  }

  Future<void> _determinerPositionGps() async {
    setState(() => _chargementGps = true);

    try {
      final serviceActive = await Geolocator.isLocationServiceEnabled();

      if (!serviceActive) {
        throw 'Le service de localisation est désactivé.';
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          throw 'Permissions refusées.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Les permissions de localisation sont refusées définitivement.';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final positionGpsLocale = LatLng(position.latitude, position.longitude);

      setState(() {
        _positionActuelle = positionGpsLocale;
        _positionChoisie = true;
      });

      _mapController.move(positionGpsLocale, 16);
    } catch (erreur) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erreur.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _chargementGps = false);
      }
    }
  }

  Future<void> _ouvrirFormulaireSignalement(
    PositionIncident positionChoisie,
  ) async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EcranFormulaireSignalement(
          position: LatLng(
            positionChoisie.latitude,
            positionChoisie.longitude,
          ),
        ),
      ),
    );

    if (resultat == true) {
      await _chargerSignalementsCarte();

      setState(() {
        _refreshSignalementsKey++;
        _indexSelectionne = 0;
      });
    }
  }

  void _ouvrirFormulaireAvecPositionActuelle() {
    if (!_positionChoisie) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez d'abord indiquer la position de l'incident."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final pos = PositionIncident(
      latitude: _positionActuelle.latitude,
      longitude: _positionActuelle.longitude,
    );

    _ouvrirFormulaireSignalement(pos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indexSelectionne,
        children: [
          _buildCorpsCarteAccueil(),
          EcranMesSignalements(
            key: ValueKey(_refreshSignalementsKey),
          ),
          const EcranMonProfil(),
        ],
      ),
      bottomNavigationBar: _modeSelection
          ? null
          : Container(
              height: 70,
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    Icons.home_filled,
                    Icons.home_filled,
                    "Accueil",
                  ),
                  _buildNavItem(
                    1,
                    Icons.bookmark_outline,
                    Icons.bookmark,
                    "Signalements",
                  ),
                  _buildNavItem(
                    2,
                    Icons.person_outline,
                    Icons.person,
                    "Profil",
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCorpsCarteAccueil() {
    final List<Marker> marqueursSignalements = [];

    for (final incident in _signalementsVoisins) {
      marqueursSignalements.add(
        Marker(
          point: incident.coordonnees,
          width: 34,
          height: 34,
          key: ValueKey(incident.id),
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
                )
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

    final Marker marqueurUtilisateur = Marker(
      point: _positionActuelle,
      width: 45,
      height: 45,
      child: Icon(
        Icons.location_on,
        color: _positionChoisie ? Colors.red : Colors.grey,
        size: 45,
      ),
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _positionActuelle,
            initialZoom: 14.0,
            onTap: (_, _) => _popupLayerController.hideAllPopups(),
            onPositionChanged: (position, hasGesture) {
              if (_modeSelection && position.center != null) {
                _positionActuelle = position.center!;
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fixcity.app',
            ),
            if (!_modeSelection)
              PopupMarkerLayer(
                options: PopupMarkerLayerOptions(
                  popupController: _popupLayerController,
                  markers: marqueursSignalements,
                  markerTapBehavior: MarkerTapBehavior.togglePopupAndHideRest(),
                  popupDisplayOptions: PopupDisplayOptions(
                    builder: (BuildContext context, Marker marker) {
                      final incident = _signalementsVoisins.firstWhere(
                        (i) => i.coordonnees == marker.point,
                        orElse: () => IncidentCommunaute(
                          id: '',
                          type: "Inconnu",
                          statut: "",
                          descriptionCourte: "",
                          coordonnees: marker.point,
                        ),
                      );

                      if (incident.type == "Inconnu") {
                        return const SizedBox.shrink();
                      }

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
                          width: 210,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                incident.type,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                incident.descriptionCourte.isEmpty
                                    ? "Aucune description."
                                    : incident.descriptionCourte,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _obtenirCouleurStatut(
                                        incident.statut,
                                      ),
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
            MarkerLayer(
              markers: [
                ...marqueursSignalements,
                marqueurUtilisateur,
              ],
            ),
          ],
        ),

        if (_modeSelection)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_searching_rounded,
                color: CouleursApp.primaire,
                size: 45,
              ),
            ),
          ),

        if (_chargementGps || _chargementSignalements)
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: CouleursApp.primaire,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _chargementGps
                            ? "Localisation en cours..."
                            : "Chargement des signalements...",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 0.8],
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (!_modeSelection)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.4, 0.7],
                    colors: [
                      Colors.white.withOpacity(1.0),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          top: 70,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        if (!_modeSelection) ...[
          Positioned(
            bottom: 130,
            left: 45,
            right: 45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionCircle(
                  Icons.map,
                  "Choisir sur la carte",
                  () {
                    setState(() => _modeSelection = true);
                  },
                ),
                _buildActionCircle(
                  Icons.my_location,
                  "Ma position",
                  _determinerPositionGps,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 35,
            left: 30,
            right: 30,
            child: SizedBox(
              height: 70,
              child: ElevatedButton.icon(
                onPressed: _ouvrirFormulaireAvecPositionActuelle,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                ),
                label: const Text(
                  "Signaler un incident",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 1,
                ),
              ),
            ),
          ),
        ] else ...[
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _modeSelection = false);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        "Annuler",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _modeSelection = false;
                          _positionChoisie = true;
                        });

                        _mapController.move(_positionActuelle, 15);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CouleursApp.primaire,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Valider la position",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        onTap: () {
          setState(() => _indexSelectionne = index);

          if (index == 0) {
            _chargerSignalementsCarte();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: estSelectionne ? const Color(0xFF006D41) : Colors.transparent,
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
                color: estSelectionne ? Colors.white : const Color(0xFF00964F),
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color:
                      estSelectionne ? Colors.white : const Color(0xFF00964F),
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

  Widget _buildActionCircle(
    IconData icone,
    String texte,
    VoidCallback auClic,
  ) {
    return GestureDetector(
      onTap: auClic,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              icone,
              color: CouleursApp.primaire,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texte,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}