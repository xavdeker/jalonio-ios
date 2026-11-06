# Publication sur l'App Store

État au 2026-11-06 : **rien n'est créé chez Apple**. Ces étapes demandent un compte et
des décisions de l'utilisateur (point I1 de `docs/points-a-trancher.md` du dépôt `jalonio`).

## 1. Compte et identifiant

1. Adhérer à l'Apple Developer Program (abonnement annuel), au nom de KersAI Factory.
   Une entreprise individuelle s'inscrit comme « individual » : le nom affiché sur
   l'App Store est alors celui de la personne.
2. Créer l'identifiant d'application `fr.jalonio.app` (Certificates, Identifiers & Profiles).
   Aucune capacité particulière : ni notifications poussées, ni iCloud, ni connexion avec Apple.
3. Créer l'application dans App Store Connect : nom « Jalonio », langue principale
   français, SKU `jalonio-ios`.

## 2. Signature et envoi

Une clé d'API App Store Connect (fichier `.p8`, rôle « App Manager ») permet d'envoyer
une version sans ouvrir Xcode. Comme pour Android, elle reste **hors du dépôt**
(`~/jalonio-keystore/`) et doit être sauvegardée ailleurs.

L'envoi demande un Mac, ou la CI macOS de GitHub avec la clé en secret chiffré
(`APP_STORE_CONNECT_KEY`). Script à écrire une fois le compte créé (`deploy-ios.sh`) :
archive Release, export signé, envoi vers TestFlight, puis promotion en production.

## 3. Fiche

| Élément | Source |
|---|---|
| Nom, sous-titre, description, mots-clés | Fiche Play Store (`jalonio-android/docs/play-store.md`), six langues |
| Captures iPhone 6,9 pouces (1320 × 2868) et iPad 13 pouces (2064 × 2752) | Parcours des tests d'interface (artefact `parcours-xcresult`), à refaire sur ces simulateurs |
| Icône 1024 px | `Jalonio/Resources/Assets.xcassets/AppIcon.appiconset` (`store/generate.mjs`) |
| Politique de confidentialité | https://app.jalonio.fr/confidentialite/ |
| Assistance | https://jalonio.fr/aide/ |

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
