# FixCity
## Resume
FixCity est une application mobile de signalement d'incidents urbains en Algérie.Le citoyen signale un problème (voirie, éclairage publique, assainissement, etc),le signalement est envoyé vers le plus proche service publique concerné pour procéder à son traitement, facilitant ainsi la communication entre les citoyens et autorités publiques.

## Fonctionnalités principales

### 1. Espace Citoyen (Application Mobile)
* **Signalement géolocalisé d'incidents :** Permet aux citoyens de signaler les dégradations urbaines en y joignant une photo et une position GPS précise.
* **Interface cartographique interactive :** Positionnement dynamique du curseur (initialement en bas de l'écran pour inviter à cliquer, puis centré avec possibilité de faire glisser la carte en dessous pour affiner l'emplacement).
* **Suivi des requêtes :** Consultation de l'état d'avancement des signalements soumis par le citoyen.

### 2. Espace Services Publics (Application Mobile)
* **Authentification dédiée :** Connexion sécurisée pour chaque service public via un compte créé et géré depuis le panneau d'administration Django.
* **Filtrage par entité :** Chaque service public accède uniquement et exclusivement aux signalements qui lui sont spécifiquement affectés.
* **Double mode d'affichage des signalements :**
  * **Vue Cartographique :** Affichage exclusif des incidents au statut **"Nouveau"** et **"En cours de traitement"** pour une intervention rapide sur le terrain.
  * **Vue Liste (Section Signalements) :** Vue d'ensemble exhaustive de tous les signalements reçus.
* **Gestion du cycle de vie :** Possibilité de mettre à jour et de changer le statut de chaque signalement (ex. en cours, résolu) au fil de sa prise en charge.

### 3. Espace Administration (Back-end Django / Web)
* **Gestion centralisée des données :** Accès global à l'ensemble des données de l'application (utilisateurs, signalements, catégories).
* **Gestion des comptes des services publics :** Création et configuration des accès (comptes) pour chaque service public, leur permettant de se connecter à l'application mobile et de traiter les signalements qui leur sont routés.

##Arborescence du projet

```text
fixcity-app/
│
├── backend/                      # Logique serveur et API (Python / Django)
│   ├── app/                      # Application principale (modèles, vues, sérialiseurs)
│   │   ├── migrations/           # Fichiers de migration de la base de données (PostgreSQL / PostGIS)
│   │   ├── admin.py              # Configuration du panneau d'administration Django
│   │   ├── models.py             # Définition des modèles de données de l'application
│   │   ├── serializers.py        # Sérialiseurs pour l'API REST
│   │   ├── urls.py               # Routage des URLs spécifiques à l'application
│   │   └── views.py              # Logique des vues, endpoints API
│   │
│   ├── config/                   # Configuration globale du projet Django
│   │   ├── __init__.py
│   │   ├── asgi.py               # Configuration asynchrone
│   │   ├── settings.py           # Paramètres globaux (base de données, apps installées, sécurité)
│   │   ├── urls.py               # Routage des URLs principales (admin et API)
│   │   └── wsgi.py               # Configuration WSGI pour le déploiement
│   │
│   ├── .env.example              # Modèle de configuration des variables d'environnement
│   ├── environment.yml           # Fichier contenant les dépendances nécessaires au le fonctionnement du backend
│   └── manage.py                 # Utilitaire en ligne de commande Django
│
├── frontend/                     # Application mobile multiplateforme (Dart / Flutter)
│   ├── android/                  # Code natif spécifique à la plateforme Android
│   ├── ios/                      # Code natif spécifique à la plateforme iOS
│   ├── windows/                  # Configuration pour l'application de bureau Windows
│   ├── macos/                    # Configuration pour l'application de bureau macOS
│   ├── linux/                    # Configuration pour l'application de bureau Linux
│   ├── web/                      # Configuration pour la version Web
│   ├── assets/                   # Ressources statiques (images, icônes)
│   │
│   ├── lib/                      # Code source principal de l'application (Dart)
│   │   ├── ecrans/              # Écrans et pages de l'application
│   │   │   ├── citoyen/          # Espace citoyen (formulaire de signalement, carte interactive)
│   │   │   └── admin/            # Espace services publics (vue cartographique filtrée, liste des signalements, statuts)
│   │   ├── widgets/              # Composants d'interface réutilisables
│   │   ├── services/             # Gestion des appels API et requêtes HTTP vers le back-end
│   │   └── main.dart             # Point d'entrée principal de l'application Flutter
│   │
│   ├── test/                     # Fichiers de tests unitaires et de widgets
│   ├── analysis_options.yaml     # Règles d'analyse statique du code Dart
│   ├── pubspec.lock              # Versions exactes des packages et dépendances
│   └── pubspec.yaml              # Gestion des dépendances du projet Flutter
│
├── .gitignore                    # Fichiers et dossiers ignorés par Git
└── README.md                     # Documentation officielle du projet

