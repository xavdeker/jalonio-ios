# Publication sur l'App Store

État au 2026-11-09 : version 1.0.0 (build 6.1) sur TestFlight, essayée sur iPad ; fiche
envoyée par l'API (textes en six langues, catégories, build rattaché), captures,
classement par âge (4+), contact et compte de démonstration envoyés. Reste : confidentialité
et prix dans App Store Connect, puis envoi à la vérification.

## 1. Compte et identifiant

1. Adhérer à l'Apple Developer Program (abonnement annuel), au nom de KersAI Factory.
   Une entreprise individuelle s'inscrit comme « individual » : le nom affiché sur
   l'App Store est alors celui de la personne.
2. Créer l'identifiant d'application `fr.jalonio.app` (Certificates, Identifiers & Profiles).
   Aucune capacité particulière : ni notifications poussées, ni iCloud, ni connexion avec Apple.
3. Créer l'application dans App Store Connect : nom « Jalonio », langue principale
   français, SKU `jalonio-ios`.

## 2. Signature et envoi

Une clé d'API App Store Connect (« Jalonio CI », rôle « Admin », exigé par la signature gérée par Apple, Key ID
`VRMQN6YM7C`) permet d'envoyer une version sans Mac. Comme pour Android, le fichier
`AuthKey_VRMQN6YM7C.p8` reste **hors du dépôt** (`~/jalonio-keystore/`) et doit être
sauvegardé ailleurs. Sur GitHub, il est le secret chiffré `APP_STORE_CONNECT_KEY` :

```bash
gh secret set APP_STORE_CONNECT_KEY --repo xavdeker/jalonio-ios < ~/jalonio-keystore/AuthKey_VRMQN6YM7C.p8
```

`./deploy-ios.sh` lance le workflow « TestFlight » (`.github/workflows/testflight.yml`) :
archive Release signée automatiquement (certificat et profil gérés par Apple), envoi vers
App Store Connect. Le numéro de build est celui de l'exécution du workflow ; la version
affichée (`MARKETING_VERSION`) se change dans `project.yml`. La mise en production se fait
dans App Store Connect, après essai sur TestFlight.

## 3. Fiche

`store/publish-listing.py` envoie la fiche par l'API App Store Connect (même clé) :

```bash
python3 store/publish-listing.py                       # textes, catégories, version, build
JALONIO_DEMO_PASSWORD=… JALONIO_REVIEW_CONTACT="Prénom|Nom|+33 …" \
    python3 store/publish-listing.py --captures         # + vérification et captures
```

| Élément | Source |
|---|---|
| Nom, sous-titre, mots-clés, description, texte promotionnel | `store/fiche/<langue>/` (repris de la fiche Play Store, sans nom de produit concurrent : règle 2.3.7) |
| Adresses d'assistance et du site, par langue | `store/fiche/urls.json` |
| Catégories | Économie et entreprise, puis Productivité |
| Captures iPhone 6,9 pouces (1320 × 2868) et iPad 13 pouces (2064 × 2752) | Workflow « Captures » (`gh workflow run captures.yml`), copiées dans `store/captures/` ; en français, reprises par les autres langues |
| Icône 1024 px | `Jalonio/Resources/Assets.xcassets/AppIcon.appiconset` (`store/generate.mjs`) |
| Politique de confidentialité | https://app.jalonio.fr/confidentialite/ |
| Compte de démonstration | Espace `demonstration` (données en anglais, sans double authentification), `demo@jalonio.fr`, le même que pour l'examen du Play Store ; notes dans `store/fiche/review-notes.txt` |

Le mot de passe du compte de démonstration et le contact pour Apple ne sont jamais écrits
dans le dépôt (public).

## 4. Confidentialité (« étiquettes nutritionnelles »)

Déclarer, sans pistage : adresse e-mail, nom, contenu utilisateur (tickets, commentaires),
liés à l'identité, pour le fonctionnement de l'application. Aucune donnée d'usage ni de
diagnostic : l'application n'a aucun SDK. C'est ce que dit `PrivacyInfo.xcprivacy`.

## 5. Vérification par Apple

- **Compte de démonstration obligatoire** : l'application ne sert à rien sans espace.
  Prévoir un espace de démonstration sur jalonio.fr, avec un compte sans double
  authentification, et le donner dans les notes de vérification.
- **Suppression de compte** (règle 5.1.1(v)) : l'application ne crée pas de compte ; le
  lien « Supprimer mon compte » mène à la page web dédiée, comme sur Android.
- **Chiffrement** : HTTPS seulement, exempté (`ITSAppUsesNonExemptEncryption` à `false`).
- **Connexion avec Apple** non exigée : pas de connexion par un service tiers.
