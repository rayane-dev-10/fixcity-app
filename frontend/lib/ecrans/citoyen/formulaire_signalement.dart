import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; // <--- AJOUT DU PACKAGE DE GÉOCODAGE
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
  final _descriptionController = TextEditingController();
  String? _typeIncidentSelectionne;

  final ImagePicker _picker = ImagePicker();
  File? _imageSelectionnee; 

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
    // 1. On met d'abord les coordonnées par défaut pour ne pas laisser le champ vide
    _adresseController.text = "Chargement de l'adresse...";
    // 2. On lance la recherche de la vraie adresse en tâche de fond
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
    await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    ),
  );

  final response = await request.send();

  if (response.statusCode == 200) {
    final responseData = await response.stream.bytesToString();
    final data = jsonDecode(responseData);

    return data['secure_url'];
  }

  return null;
}

  // --- 🌍 FONCTION DE GÉOCODAGE INVERSÉ ---
  Future<void> _recupererVraieAdresse() async {
    try {
      // On interroge le plugin avec la latitude et longitude reçues
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.position.latitude, 
        widget.position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        
        // On construit une belle adresse propre (Rue, Ville, Code Postal...)
        // Si la rue n'est pas détectée, on prend le nom du quartier ou de la ville
        String nomRue = place.street ?? "";
        String localite = place.locality ?? "";
        String codePostal = place.postalCode ?? "";
        
        setState(() {
          if (nomRue.isNotEmpty && nomRue != place.locality) {
            _adresseController.text = "$nomRue, $localite $codePostal".trim();
          } else {
            _adresseController.text = "$localite $codePostal".trim();
          }
        });
      }
    } catch (e) {
      // Si le téléphone n'a pas de réseau ou bug, on remet les coordonnées GPS brutes en secours
      print("Erreur geocoding : $e");
      setState(() {
        _adresseController.text = 
            "${widget.position.latitude.toStringAsFixed(5)}, ${widget.position.longitude.toStringAsFixed(5)}";
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

                // --- BOUTON FINAL : ENVOYER ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _soumettreFormulaire();
                    },
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    label: const Text(
                      "Envoyer", 
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00964F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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

  try{
    final acessToken = await SharedPreferences.getInstance().then((prefs) => prefs.getString('access_token'));
    bool isExpired = JwtDecoder.isExpired(acessToken as String);
    if(!isExpired){
       final imageUrl = await _uploadImageToCloudinary(_imageSelectionnee!);
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'envoi de l'image."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final data = {
       "latitude": widget.position.latitude,
       "longitude": widget.position.longitude,
       "wilaya": "Tizi Ouzou",
       "commune": "Tizi Ouzou",
       "adresseLisible": _adresseController.text.trim(),
       "url_image": imageUrl,
       "description": _descriptionController.text.trim(),
       "categorie": _typeIncidentSelectionne,
      };

     final response = await ApiService.creerIncident(data, acessToken);

     if (!mounted) return;

     if (response.statusCode == 201) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text("Signalement envoyé avec succès."),
           backgroundColor: Colors.green,
         ),
       );

       Navigator.pop(context, true);
      } else {
        final erreur = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(erreur.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    else{
    //rafraichir le token d'acces et réessayer
    final refreshToken = await SharedPreferences.getInstance().then((prefs) => prefs.getString('refresh_token'));
    final refreshResponse = await ApiService.refreshToken(refreshToken as String);
    if(refreshResponse.statusCode == 200){
      final data = jsonDecode(refreshResponse.body);
      final nouveauAccessToken = data['access'];
      await SharedPreferences.getInstance().then((prefs) => prefs.setString('access_token', nouveauAccessToken));
      //réessayer d'envoyer le signalement avec le nouveau token
      final imageUrl = await _uploadImageToCloudinary(_imageSelectionnee!);
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'envoi de l'image."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final dataIncident = {
       "latitude": widget.position.latitude,
       "longitude": widget.position.longitude,
       "adresseLisible": _adresseController.text.trim(),
       "wilaya": "Tizi Ouzou",
       "commune": "Tizi Ouzou",
       "url_image": imageUrl,
       "description": _descriptionController.text.trim(),
       "categorie": _typeIncidentSelectionne,
      };

     final response = await ApiService.creerIncident(dataIncident, nouveauAccessToken);

     if (!mounted) return;

      if (response.statusCode == 201) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text("Signalement envoyé avec succès."),
           backgroundColor: Colors.green,
         ),
       );

       Navigator.pop(context, true);
      }else{
        final erreur = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(erreur.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expirée. Veuillez vous reconnecter."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
 }catch(e){
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Erreur de connexion au serveur."),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}  