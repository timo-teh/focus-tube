# Focus Tube

**Un client YouTube pour apprendre, pas pour scroller.**

Focus Tube est une application macOS minimaliste qui donne accès aux vidéos YouTube
sans aucun des mécanismes conçus pour capter votre attention : pas de page d'accueil,
pas de recommandations, pas de Shorts, pas de lecture automatique, pas de compteurs.

## Philosophie

YouTube est une formidable bibliothèque de cours, de tutoriels et de conférences.
C'est aussi une machine à distraction extrêmement efficace. Focus Tube garde la
bibliothèque et retire la machine :

| Ce que fait Focus Tube | Ce qu'il ne fait pas |
|---|---|
| Une barre de recherche, rien d'autre | Pas de fil d'accueil, pas de tendances |
| Garde les catégories Éducation, Science & Tech, Howto, Actualités, Associatif, Auto, Voyage | Exclut Divertissement, Comédie, Gaming, Musique, Films, Sport, People & Blogs, Shows |
| Lit la vidéo avec le lecteur officiel YouTube | Pas de suggestions ni de vidéos liées intrusives |
| Messages de fin et d'erreur placés sous le lecteur | Pas de lecture automatique de la suivante |
| Autorise 0,5× à 1,5× | Pas de 2× pour « consommer plus vite » |
| Interface entièrement en niveaux de gris | Seule la vidéo en lecture est en couleur |
| Exclut toute vidéo ≤ 3 min ou taguée `#shorts` | Pas de Shorts |

L'application utilise uniquement l'API officielle **YouTube Data API v3** et le lecteur
officiel **YouTube IFrame Player API**. Elle ne télécharge jamais de flux vidéo et ne
contourne pas le lecteur, conformément aux conditions d'utilisation de YouTube.

## Télécharger et installer Focus Tube

1. Ouvrez la page **Releases** de ce dépôt GitHub.
2. Sélectionnez la version souhaitée.
3. Dans la section **Assets**, téléchargez `FocusTube.dmg`.
4. Ouvrez le fichier téléchargé.
5. Glissez **Focus Tube.app** dans le dossier **Applications**.
6. Ouvrez Focus Tube depuis le dossier Applications.
7. Au premier lancement, renseignez votre propre clé YouTube Data API.

L'installation et l'utilisation de Focus Tube ne nécessitent pas Xcode.

### Avertissement de sécurité macOS

Si la version téléchargée n'est pas signée avec un certificat
Developer ID et n'est pas notariée, Gatekeeper peut afficher un
avertissement ou bloquer son ouverture.

Si vous avez vérifié la provenance de l'application et souhaitez
l'ouvrir malgré cet avertissement :

1. Essayez d'ouvrir l'application.
2. Ouvrez **Réglages Système > Confidentialité et sécurité**.
3. Si l'option **Ouvrir quand même** est proposée pour Focus Tube,
   choisissez-la et confirmez.

L'apparence exacte des messages et les options disponibles peuvent
varier selon la version de macOS. Ne désactivez pas globalement
Gatekeeper.

## Publier une version

Le dépôt utilise GitHub Actions pour compiler l'application et créer
le fichier `FocusTube.dmg`.

Après avoir enregistré et envoyé les modifications sur GitHub,
utilisez un numéro de version qui n'existe pas encore :

    git tag v1.0.0
    git push origin v1.0.0

Le tag doit être au format `vMAJEUR.MINEUR.CORRECTIF`.

Ensuite :

1. Ouvrez l'onglet **Actions** du dépôt GitHub.
2. Attendez la fin du workflow **Publication macOS**.
3. Ouvrez l'onglet **Releases**.
4. Téléchargez `FocusTube.dmg` dans les fichiers de la release.

La compilation est effectuée sur le runner macOS de GitHub Actions :
Xcode n'est donc pas nécessaire sur votre propre Mac pour déclencher
la release.

La release produite par défaut n'est pas signée avec Developer ID
et n'est pas notariée.

## Lecteur vidéo

Focus Tube utilise le lecteur YouTube officiel. Pendant la pause,
l'image affichée est celle du lecteur à la position courante.

Le paramètre `rel=0` ne supprime pas toutes les vidéos liées :
YouTube peut toujours afficher des éléments dans son lecteur.

## Prérequis pour le développement

- macOS 13 Ventura ou plus récent (Apple Silicon et Intel).
- Une clé YouTube Data API v3 (gratuite, voir ci-dessous).
- Pour compiler : Xcode 14.1 ou plus récent.

## Obtenir une clé YouTube Data API

1. Rendez-vous sur [console.cloud.google.com](https://console.cloud.google.com/) et connectez-vous avec un compte Google.
2. En haut de la page, cliquez sur le sélecteur de projet puis **Nouveau projet**. Donnez-lui un nom (par exemple `focus-tube`) et créez-le.
3. Dans le menu, ouvrez **API et services › Bibliothèque**.
4. Cherchez **YouTube Data API v3** et cliquez sur **Activer**.
5. Ouvrez **API et services › Identifiants**, puis **Créer des identifiants › Clé API**.
6. Copiez la clé affichée.
7. Recommandé : cliquez sur la clé pour la modifier, et dans **Restrictions relatives aux API**, choisissez *Restreindre la clé* › cochez uniquement **YouTube Data API v3**. Ainsi, même si la clé fuit, elle ne sert à rien d'autre.

Au premier lancement, Focus Tube vous demande cette clé. Elle est validée par un appel
d'une unité puis stockée dans le **Trousseau macOS**. Elle n'est jamais écrite dans un
fichier et n'apparaît nulle part dans le code.

### À propos du quota

Chaque projet Google dispose de **10 000 unités par jour**. Une recherche dans Focus Tube
coûte **101 unités** (100 pour `search.list` + 1 pour `videos.list`), soit environ
**99 recherches par jour**. Pour économiser le quota :

- les résultats sont mis en cache pendant 24 h (une recherche identique ne coûte rien) ;
- un compteur estimé est affiché en bas de l'écran de recherche ;
- en cas de dépassement, un message clair est affiché. Le quota se réinitialise à minuit,
  heure du Pacifique (vers 9 h à Paris).

## Compiler avec Xcode

```bash
git clone https://github.com/timo-teh/focus-tube.git
cd focus-tube
open Package.swift
```

Dans Xcode : `Product > Run` (⌘R). L'app se lance sans configuration supplémentaire.

## Compiler en ligne de commande

Le script de build release produit un bundle universel et une image disque DMG :

```bash
bash Scripts/build-release.sh 1.2.1
```

Sortie : `dist/Focus Tube.app` et `dist/FocusTube.dmg` (binaire arm64 + x86_64, signé ad hoc).

Vérifier le binaire :

```bash
lipo -info "dist/Focus Tube.app/Contents/MacOS/FocusTube"
codesign --verify --verbose "dist/Focus Tube.app"
```

## Utilisation

1. **Écran de configuration** (premier lancement) : collez votre clé API. Elle est testée immédiatement.
2. **Recherche** : tapez un sujet précis (« grammaire japonaise », « système solaire », « soudure à l'arc »). Seules les vidéos des catégories autorisées et de plus de 3 minutes sont affichées, en niveaux de gris.
3. **Lecture** : le lecteur YouTube officiel s'ouvre avec ses commandes natives. Vitesses disponibles : 0,5× à 1,5×. Pendant la pause, l'image reste directement visible. Les messages de fin et d'erreur sont placés sous le lecteur.
4. **Quota** : suivi en bas de l'écran. Les recherches identiques (à 24 h) sont servies depuis le cache local (`~/Library/Application Support/FocusTube/search-cache.json`).

Menu ⚙️ : changer la clé API ou vider le cache.

## Personnaliser le filtre

Le cœur du filtrage est dans `Sources/FocusTube/Config/AllowedCategories.swift` :

```swift
static let ids: Set<String> = ["2", "19", "25", "26", "27", "28", "29"]
```

Ajoutez ou retirez un identifiant YouTube pour élargir ou restreindre le filtre. Autres réglages dans `AppConfig.swift` : durée minimale, vitesse max, TTL du cache.

## Commentaires

- Les commentaires de la vidéo sont affichés sous la description (auteur, ancienneté, texte,
  réponses), sans aucun compteur. Chaque page coûte 1 unité de quota. Tri et taille de page dans
  `Sources/FocusTube/Config/CommentsConfig.swift`.

## Sous-titres et langue audio

- Les sous-titres et la langue audio peuvent être configurés dans `Sources/FocusTube/Config/LanguagesConfig.swift` ou directement via les contrôles du lecteur.

## Confidentialité

- Aucune donnée ne quitte votre machine sauf les requêtes vers `www.googleapis.com/youtube/v3` (recherche) et `www.youtube.com` (lecture).
- La clé API est stockée uniquement dans le Trousseau macOS (`com.focustube.app`).
- Pas de télémétrie, pas de compte, pas de publicité.

## Licence

MIT — voir [LICENSE](LICENSE).

## Note technique : identification auprès du lecteur YouTube

Depuis 2025, YouTube exige que toute page intégrant son lecteur envoie un en-tête HTTP `Referer`
en https identifiant le site ou l'application hôte ; sinon le lecteur affiche l'erreur 152 ou 153.
Focus Tube charge donc sa page de lecteur avec pour base `https://com.focustube.app` (son identifiant
de bundle, voir `Sources/FocusTube/Player/PlayerOrigin.swift`). Cette adresse ne pointe vers aucun
serveur : elle sert uniquement d'identité, pratique employée par plusieurs SDK pour les applications
natives. Aucune requête n'est envoyée ailleurs que vers YouTube.
