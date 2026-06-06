import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class EcranFormulaireSignalement extends StatefulWidget {
  final LatLng position; 

  const EcranFormulaireSignalement({super.key, required this.position});

  @override
  State<EcranFormulaireSignalement> createState() => _EcranFormulaireSignalementState();
}

class _EcranFormulaireSignalementState extends State<EcranFormulaireSignalement> {
  final _formKey = GlobalKey<FormState>();
  
  final _adresseController = TextEditingController();
  String _wilayaExtraite = "Tizi Ouzou";
  String _communeExtraite = "Tizi Ouzou";
  final _descriptionController = TextEditingController();
  String? _typeIncidentSelectionne;

  final ImagePicker _picker = ImagePicker();
  File? _imageSelectionnee; 
  
  // --- NOUVEAU : Variable pour gérer l'état de chargement
  bool _isLoading = false;

  final List<String> _typesIncidents = [
    'Assainissement',
    'Espace Publique',
    'Déchets',
    'Eclairage Publique',
    'Voirie',
  ];

  @override
  void initState() {
    super.initState();
    _adresseController.text = "Chargement de l'adresse...";
    _recupererVraieAdresse();
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final cloudName = 'mounircld';
    final uploadPreset = 'fixcity_preset';

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final data = jsonDecode(responseData);
      return data['secure_url'];
    }

    return null;
  }

  Future<void> _recupererVraieAdresse() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.position.latitude, 
        widget.position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        
        String nomRue = place.street ?? "";
        String localite = place.locality ?? "";
        String administrativeArea = place.administrativeArea ?? "";
        String codePostal = place.postalCode ?? "";
        
        String wilaya = place.administrativeArea ?? place.subAdministrativeArea ?? place.locality ?? "";
        wilaya = wilaya
            .replaceAll(RegExp(r"Wilaya de|Province de|Wilaya d\' |Province|Wilaya", caseSensitive: false), '')
            .trim();

        String commune = place.subAdministrativeArea ?? place.locality ?? place.subLocality ?? "";
        commune = commune
            .replaceAll(RegExp(r"Daïra de |Commune de|Daïra d\'|Commune d\'|Commune|Municipality|Daïra|Town|City", caseSensitive: false), '')
            .trim();

        setState(() {
          _wilayaExtraite = wilaya.isNotEmpty ? wilaya : "Tizi Ouzou";
          _communeExtraite = commune.isNotEmpty ? commune : "Tizi Ouzou";

          if (nomRue.isNotEmpty && nomRue != place.locality && nomRue != place.administrativeArea) {
            _adresseController.text = "$nomRue, $_communeExtraite,$_wilayaExtraite".trim();
          } else {
            _adresseController.text = "$localite $codePostal".trim();
          }
        });
      }
    } catch (e) {
      setState(() {
        _adresseController.text = 
            "${widget.position.latitude.toStringAsFixed(5)}, ${widget.position.longitude.toStringAsFixed(5)}";

        _wilayaExtraite = "Tizi Ouzou";
        _communeExtraite = "Tizi Ouzou";    
      });
    }
  }

  Future<void> _recupererImageGalerie() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageSelectionnee = File(image.path);
      });
    }
  }

  Future<void> _prendrePhotoCamera() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _imageSelectionnee = File(photo.path);
      });
    }
  }

  @override
  void dispose() {
    _adresseController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- FONCTION DE SOUMISSION OPTIMISÉE ET CORRIGÉE ---
  Future<void> _soumettreFormulaire() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageSelectionnee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez ajouter une photo de l'incident."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Début du chargement
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('access_token');
      bool isExpired = accessToken == null || JwtDecoder.isExpired(accessToken);

      // 1. Vérification et rafraîchissement du token AVANT l'upload de l'image
      if (isExpired) {
        final refreshToken = prefs.getString('refresh_token');
        if (refreshToken != null) {
          final refreshResponse = await ApiService.refreshToken(refreshToken);
          if (refreshResponse.statusCode == 200) {
            final tokenData = jsonDecode(refreshResponse.body); // NOUVEAU NOM : tokenData
            accessToken = tokenData['access'];
            await prefs.setString('access_token', accessToken!);
          } else {
            throw Exception("Session expirée");
          }
        } else {
          throw Exception("Session expirée");
        }
      }

      // 2. Upload de l'image (une seule fois maintenant !)
      final imageUrl = await _uploadImageToCloudinary(_imageSelectionnee!);
      
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'envoi de l'image."), backgroundColor: Colors.red),
        );
        setState(() { _isLoading = false; });
        return;
      }

      // 3. Préparation des données de l'incident (NOUVEAU NOM : incidentData)
      final incidentData = {
        "latitude": widget.position.latitude,
        "longitude": widget.position.longitude,
        "wilaya": _wilayaExtraite,
        "commune": _communeExtraite,
        "adresseLisible": _adresseController.text.trim(),
        "url_image": imageUrl,
        "description": _descriptionController.text.trim(),
        "categorie": _typeIncidentSelectionne,
      };

      // 4. Envoi de la requête au serveur
      final response = await ApiService.creerIncident(incidentData, accessToken);

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signalement envoyé avec succès."), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        final erreur = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erreur.toString()), backgroundColor: Colors.red),
        );
      }

    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains("Session expirée")) {
       //redirection vers login
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        print ("wilaya= $_wilayaExtraite");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur de connexion au serveur."), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Fin du chargement peu importe le résultat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Signaler un incident",
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // --- SECTION 1 : PHOTO ---
                _buildSectionCadre(
                  titre: "Photo",
                  child: Column(
                    children: [
                      Center(
                        child: _imageSelectionnee != null
                            ? _buildApercuImageReelle(_imageSelectionnee!)
                            : _buildCaseImageVide(),
                      ),
                      const SizedBox(height: 20),
                      _buildBoutonActionPhoto(
                        icone: Icons.file_upload_outlined,
                        label: "Ajouter une image",
                        auClic: _recupererImageGalerie,
                      ),
                      const SizedBox(height: 12),
                      _buildBoutonActionPhoto(
                        icone: Icons.camera_alt_outlined,
                        label: "Prendre une photo",
                        auClic: _prendrePhotoCamera,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- SECTION 2 : INFORMATIONS ---
                _buildSectionCadre(
                  titre: "Informations",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Adresse', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _adresseController,
                        readOnly: true, 
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]), 
                        decoration: _buildInputDecoration(hint: "").copyWith(
                          fillColor: Colors.grey[100], 
                          prefixIcon: const Icon(Icons.pin_drop_rounded, color: Colors.black87, size: 20), 
                        ),
                      ),
                      
                      const SizedBox(height: 18),

                      const Text('Type d’incident', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _typeIncidentSelectionne,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: _buildInputDecoration(hint: "Sélectionner le type"),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                        items: _typesIncidents.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (valeur) {
                          setState(() {
                            _typeIncidentSelectionne = valeur;
                          });
                        },
                        validator: (v) => v == null ? "Veuillez choisir un type d'incident" : null,
                      ),

                      const SizedBox(height: 18),

                      const Text('Description (optionnelle)', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14),
                        decoration: _buildInputDecoration(hint: "Décrivez le problème constaté..."),
                        validator: (_) => null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- BOUTON FINAL : ENVOYER (AVEC LOADING) ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      await _soumettreFormulaire();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00964F),
                      disabledBackgroundColor: const Color(0xFF00964F).withOpacity(0.7), // Couleur pendant le chargement
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Envoyer", 
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCadre({required String titre, required Widget child}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: titre,
        labelStyle: const TextStyle(color: Color(0xFF00964F), fontSize: 18, fontWeight: FontWeight.bold),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: child,
      ),
    );
  }

  Widget _buildApercuImageReelle(File imageFile) {
    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: FileImage(imageFile),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _imageSelectionnee = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseImageVide() {
    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.grey, size: 34),
          SizedBox(height: 8),
          Text(
            "Aucune image sélectionnée",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutonActionPhoto({required IconData icone, required String label, required VoidCallback auClic}) {
    return SizedBox(
      width: 220,
      height: 40,
      child: ElevatedButton.icon(
        onPressed: auClic,
        icon: Icon(icone, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00964F), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}