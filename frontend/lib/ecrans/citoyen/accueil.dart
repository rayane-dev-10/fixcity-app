import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../utils/couleurs_app.dart';
import '../citoyen/formulaire_signalement.dart';
import '../citoyen/detail_signalement_citoyen.dart';
import '../citoyen/mon_profil.dart';
import '../citoyen/signalements.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../auth/login.dart';
class IncidentCommunaute {
  final String id;
  final String type;
  final String statut;
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

  factory IncidentCommunaute.fromJson(Map<String, dynamic> json) {
    final citoyen = json['citoyen'];
    final utilisateur = json['utilisateur'];
    final user = json['user'];

    return IncidentCommunaute(
      id: json['id'].toString(),
      type: json['categorie']?.toString() ?? 'Type inconnu',
      statut: _normaliserStatut(json['statut']?.toString() ?? ''),
      descriptionCourte: json['description']?.toString() ?? '',
      coordonnees: LatLng(
        double.tryParse(
              json['lat']?.toString() ??
                  json['latitude']?.toString() ??
                  '',
            ) ??
            0,
        double.tryParse(
              json['long']?.toString() ??
                  json['longitude']?.toString() ??
                  '',
            ) ??
            0,
      ),
      imageUrl: json['url_image']?.toString() ??
          json['imageUrl']?.toString() ??
          json['image_url']?.toString() ??
          json['photo']?.toString() ??
          '',
      dateSignalement: json['date_signalement']?.toString() ??
          json['dateSignalement']?.toString() ??
          json['created_at']?.toString() ??
          json['date_creation']?.toString() ??
          json['date']?.toString() ??
          '',
      citoyenEmail: json['citoyen_email']?.toString() ??
          json['email_citoyen']?.toString() ??
          (citoyen is String ? citoyen : null) ??
          (citoyen is Map ? citoyen['email']?.toString() : null) ??
          (utilisateur is String ? utilisateur : null) ??
          (utilisateur is Map ? utilisateur['email']?.toString() : null) ??
          (user is String ? user : null) ??
          (user is Map ? user['email']?.toString() : null) ??
          '',
      adresseLisible: json['adresseLisible']?.toString() ??
          json['adresse_lisible']?.toString() ??
          json['adresse']?.toString() ??
          json['localisation_adresse']?.toString() ??
          '',
    );
  }

  static String _normaliserStatut(String statutBackend){
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
  final TextEditingController _rechercheLieuController = TextEditingController();
  Timer? _debounceRecherche;

  bool _modeSelection = false;
  bool _chargementGps = false;
  bool _chargementRechercheLieu = false;
  bool _chargementSuggestions = false;
  bool _chargementSignalements = false;
  bool _positionChoisie = false;

  LatLng _positionActuelle = LatLng(36.7118, 4.0459);
  LatLng? _positionAvantSelectionCarte;
  LatLng? _centreCarteAvantSelection;
  double? _zoomCarteAvantSelection;

  List<IncidentCommunaute> _signalementsVoisins = [];
  List<Map<String, dynamic>> _suggestionsLieux = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _rechercheLieuController.dispose();
    _popupLayerController.dispose();
    super.dispose();
  }


Future<void> _rechercherLieu() async {
  final recherche = _rechercheLieuController.text.trim();

  if (recherche.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Veuillez écrire un lieu à rechercher."),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  FocusScope.of(context).unfocus();
  setState(() => _chargementRechercheLieu = true);

  try {
    await _chercherSuggestionsLieux(recherche, afficherChargement: false);

    if (!mounted) return;

    if (_suggestionsLieux.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucun lieu trouvé."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _selectionnerSuggestionLieu(_suggestionsLieux.first);
  } catch (erreur) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Lieu introuvable : ${erreur.toString()}"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _chargementRechercheLieu = false);
    }
  }
}

Future<void> _chercherSuggestionsLieux(
  String texte, {
  bool afficherChargement = true,
}) async {
  final recherche = texte.trim();

  if (recherche.length < 3) {
    if (!mounted) return;
    setState(() {
      _suggestionsLieux = [];
      _chargementSuggestions = false;
    });
    return;
  }

  if (afficherChargement) {
    setState(() => _chargementSuggestions = true);
  }

  try {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': recherche,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'dz',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'FixCity/1.0 (psdmounir@gmail.com)',
        'Accept': 'application/json',
      },
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        setState(() {
          _suggestionsLieux = data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } else {
      setState(() => _suggestionsLieux = []);
    }
  } catch (_) {
    if (!mounted) return;
    setState(() => _suggestionsLieux = []);
  } finally {
    if (mounted && afficherChargement) {
      setState(() => _chargementSuggestions = false);
    }
  }
}

Future<void> _selectionnerSuggestionLieu(Map<String, dynamic> lieu) async {
  final latitude = double.tryParse(lieu['lat']?.toString() ?? '');
  final longitude = double.tryParse(lieu['lon']?.toString() ?? '');
  final nomLieu = lieu['display_name']?.toString() ?? '';

  if (latitude == null || longitude == null) return;

  final nouvellePosition = LatLng(latitude, longitude);

  setState(() {
    _positionActuelle = nouvellePosition;
    _positionChoisie = true;
    _modeSelection = false;
    _rechercheLieuController.text = nomLieu;
    _suggestionsLieux = [];
  });

  FocusScope.of(context).unfocus();
  _popupLayerController.hideAllPopups();
  _mapController.move(nouvellePosition, 16);

  await _chargerSignalementsCarte();
}

Future<void> _chargerSignalementsCarte() async {
  if (!_positionChoisie) return;

  setState(() => _chargementSignalements = true);

  // 1. On récupère correctement le token avec "await"
  final prefs = await SharedPreferences.getInstance();
  final accessToken = prefs.getString('access_token');

  // Si le token n'existe même pas, on gère l'expiration directement
  bool isExpired = accessToken == null || JwtDecoder.isExpired(accessToken);

  if (!isExpired) {
    final response = await ApiService.listeIncidentsProches(
      accessToken, 
      _positionActuelle.latitude,
      _positionActuelle.longitude,
    );

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
    } else if (response.statusCode == 404) {
      setState(() {
        _signalementsVoisins = [];
        _chargementSignalements = false;
      });
    } else {
      setState(() => _chargementSignalements = false);
    }
  } else { 
    // Le token d'accès est expiré ou inexistant, on tente de le rafraîchir
    final refreshToken = prefs.getString('refresh_token');
    
    if (refreshToken == null) {
      _redirectionLogin();
      return;
    }

    final response = await ApiService.refreshToken(refreshToken);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccess = data['access'];
      await prefs.setString('access_token', newAccess);
      
      // Relance la fonction pour charger les données avec le nouveau token
      await _chargerSignalementsCarte();
    } else {
      // Échec du rafraîchissement -> On coupe le chargement et on redirige
      _redirectionLogin();
    }
  }
}

// Petite fonction d'aide pour éviter la répétition du code de redirection
void _redirectionLogin() {
  setState(() => _chargementSignalements = false);
  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const EcranLogin()),
  );
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
    // 1. Vérifier si le service GPS est activé sur le téléphone
    final serviceActive = await Geolocator.isLocationServiceEnabled();
    if (!serviceActive) {
      throw 'Veuillez activer le service de localisation (GPS) de votre appareil.';
    }

    // 2. Vérifier le statut actuel des permissions
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Permissions de localisation refusées.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Les permissions sont refusées définitivement. Veuillez les activer dans les paramètres.';
    }

    // 3. Optimisation : On tente d'abord de récupérer la dernière position connue (instantané)
    Position? position = await Geolocator.getLastKnownPosition();

    // Si pas de dernière position connue, on demande la position actuelle
    position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8), // Évite un chargement infini si le signal est mauvais
      );

    // --- SÉCURITÉ : On vérifie si l'écran est toujours affiché ---
    if (!mounted) return;

    final positionGpsLocale = LatLng(position.latitude, position.longitude);

    setState(() {
      _positionActuelle = positionGpsLocale;
      _positionChoisie = true;
    });

    // Interaction avec la carte
    _mapController.move(positionGpsLocale, 16);
    
    // Appel de votre méthode de chargement des marqueurs
    await _chargerSignalementsCarte();

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
          content: Text("Veuillez indiquer la position de l'incident."),
          backgroundColor: Color.fromARGB(255, 255, 0, 0),
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


  void _ouvrirDetailsSignalement(IncidentCommunaute incident) {
    _popupLayerController.hideAllPopups();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EcranDetailSignalementCitoyen(
          id: incident.id,
          type: incident.type,
          statut: incident.statut,
          description: incident.descriptionCourte,
          coordonnees: incident.coordonnees,
          imageUrl: incident.imageUrl,
          dateSignalement: incident.dateSignalement,
          citoyenEmail: incident.citoyenEmail,
          adresseLisible: incident.adresseLisible,
        ),
      ),
    );
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



    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _positionActuelle,
            initialZoom: 14.0,
            onTap: (_, _) {
              _popupLayerController.hideAllPopups();
              FocusScope.of(context).unfocus();

              setState(() {
                _suggestionsLieux = [];
              });
            },
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
            MarkerLayer(
              markers: [
                if (_positionChoisie)
                  Marker(
                    point: _positionActuelle,
                    width: 45,
                    height: 45,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 45,
                    ),
                  ),
              ],
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
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton(
                                  onPressed: () => _ouvrirDetailsSignalement(incident),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: CouleursApp.primaire,
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Voir détails",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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

        if (!_modeSelection)
          Positioned(
            top: 135,
            left: 35,
            right: 35,
            child: _buildBarreRechercheLieu(),
          ),

        if (_chargementGps || _chargementRechercheLieu || _chargementSignalements)
          Positioned(
            top: 190,
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
                            : _chargementRechercheLieu
                                ? "Recherche du lieu..."
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
                    setState(() {
                      _positionAvantSelectionCarte = _positionActuelle;
                      _centreCarteAvantSelection = _mapController.camera.center;
                      _zoomCarteAvantSelection = _mapController.camera.zoom;
                      _modeSelection = true;
                    });
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
                        final anciennePosition = _positionAvantSelectionCarte;
                        final ancienCentreCarte = _centreCarteAvantSelection;
                        final ancienZoomCarte = _zoomCarteAvantSelection;

                        setState(() {
                          _modeSelection = false;

                          if (anciennePosition != null) {
                            _positionActuelle = anciennePosition;
                          }

                          _positionAvantSelectionCarte = null;
                          _centreCarteAvantSelection = null;
                          _zoomCarteAvantSelection = null;
                        });

                        if (ancienCentreCarte != null && ancienZoomCarte != null) {
                          _mapController.move(ancienCentreCarte, ancienZoomCarte);
                        }
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
                    onPressed: () async {
                    setState(() {
                      _modeSelection = false;
                      _positionChoisie = true;
                      _positionAvantSelectionCarte = null;
                      _centreCarteAvantSelection = null;
                      _zoomCarteAvantSelection = null;
                     });

                      _mapController.move(_positionActuelle, 15);
                      await _chargerSignalementsCarte();
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

          if (index == 0 && _positionChoisie) {
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


  Widget _buildBarreRechercheLieu() {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _rechercheLieuController,
              textInputAction: TextInputAction.search,
              onChanged: (valeur) {
                setState(() {});
                _debounceRecherche?.cancel();
                _debounceRecherche = Timer(
                  const Duration(milliseconds: 500),
                  () => _chercherSuggestionsLieux(valeur),
                );
              },
              onSubmitted: (_) => _rechercherLieu(),
              decoration: InputDecoration(
                hintText: "Rechercher un lieu...",
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF00964F),
                  size: 21,
                ),
                suffixIcon: _chargementSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _rechercheLieuController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 19),
                            color: Colors.grey,
                            onPressed: () {
                              _debounceRecherche?.cancel();
                              setState(() {
                                _rechercheLieuController.clear();
                                _suggestionsLieux = [];
                              });
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 21),
                            color: const Color(0xFF00964F),
                            onPressed: _rechercherLieu,
                          ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),

          if (_suggestionsLieux.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 230),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestionsLieux.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final lieu = _suggestionsLieux[index];
                  final nom = lieu['display_name']?.toString() ?? 'Lieu inconnu';

                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: Color(0xFF00964F),
                      size: 20,
                    ),
                    title: Text(
                      nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _selectionnerSuggestionLieu(lieu),
                  );
                },
              ),
            ),
        ],
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