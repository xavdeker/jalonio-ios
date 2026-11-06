# Jalonio iOS

Application iPhone et iPad de [Jalonio](https://jalonio.fr), le gestionnaire de projets
souverain de KersAI Factory. Elle se connecte à n'importe quel espace Jalonio :
`<espace>.jalonio.fr` ou une installation sur site. Licence EUPL 1.2.

Le serveur (jetons mobiles, ADR-0029) et la décision iOS (ADR-0031) sont dans le dépôt
`jalonio`. L'application reprend les écrans de l'application Android (`jalonio-android`).

## Ce que fait la version 1.0.0

- Connexion à un espace (adresse saisie), mot de passe et double authentification.
- Accueil « Mes tickets », projets et tickets par statut (recherche), fiche ticket
  (statut, « M'assigner », description, sous-tâches, activité, commentaire), création
  rapide, notifications de l'application web, compte (liens, déconnexion).
- **iPad** : colonnes (projets → tickets → fiche) avec `NavigationSplitView`, toutes
  orientations, plusieurs fenêtres.
- Six langues : français, anglais (langue de repli), allemand, espagnol, italien,
  portugais ; choix par application dans les Réglages d'iOS.
- Accessibilité : VoiceOver, Dynamic Type, audit d'accessibilité d'Xcode sur chaque écran.

**Aucun service tiers** : ni SDK d'analyse ou de plantages, ni notifications poussées
(APNs). Jetons dans le trousseau, liés à l'appareil (pas de sauvegarde iCloud).

## Organisation

| Dossier | Contenu |
|---|---|
| `JalonioKit/` | Cœur sans interface (paquet Swift) : modèles de l'API, adresse de l'espace, jetons, client HTTP avec rafraîchissement sérialisé, logique de présentation. `swift test` |
| `JalonioKit/Tests/…/Fixtures/` | Vraies réponses du backend de test (mêmes jeux d'essai qu'Android) |
| `Jalonio/Sources/` | Application SwiftUI (iOS 17) |
| `Jalonio/Resources/` | Textes des six langues (`scripts/strings.py`), images, manifeste de confidentialité |
| `Jalonio/Demo/` | Faux serveur des tests d'interface (`-ui-demo`), exclu de la version publiée |
| `JalonioUITests/` | Parcours complet sur iPhone et iPad, audit d'accessibilité, captures |
| `project.yml` | Projet Xcode décrit en texte ([XcodeGen](https://github.com/yonaskolb/XcodeGen)) |

## Compiler et tester

Sur un Mac avec Xcode 16 ou plus récent :

```bash
brew install xcodegen
xcodegen generate                       # produit Jalonio.xcodeproj (non versionné)
(cd JalonioKit && swift test)           # cœur : décodage, adresse, jetons
xcodebuild test -project Jalonio.xcodeproj -scheme Jalonio \
  -destination "platform=iOS Simulator,name=iPhone 16"
open Jalonio.xcodeproj                  # puis ⌘R
```

Sans Mac, la CI GitHub (`.github/workflows/ci.yml`, macOS) fait tout cela à chaque
envoi : tests du cœur, parcours sur un iPhone et un iPad simulés, compilation Release
sans signature. Les captures du parcours sont dans l'artefact `parcours-xcresult`.

Serveur local : saisir `http://localhost:3000` comme adresse d'espace (le clair n'est
permis que vers `localhost`).

## Textes

`python3 scripts/strings.py` reprend les traductions d'Android
(`../jalonio-android`) et y ajoute les textes propres à iOS (`EXTRA` dans le script).
Les fichiers produits sont versionnés.

## Publier

Rien n'est encore créé chez Apple : compte développeur, identifiant `fr.jalonio.app`,
fiche App Store. Voir `docs/app-store.md`.
