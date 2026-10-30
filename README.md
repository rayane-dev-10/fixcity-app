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
