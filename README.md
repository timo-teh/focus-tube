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
| Lit la vidéo avec le lecteur officiel YouTube | Pas de suggestions, de commentaires ni de vidéos liées |
| Masque l'écran de fin et affiche « Vidéo terminée » | Pas de lecture automatique de la suivante |
| Autorise 0,5× à 1,5× | Pas de 2× pour « consommer plus vite » |
| Interface entièrement en niveaux de gris | Seule la vidéo en lecture est en couleur |
| Exclut toute vidéo ≤ 3 min ou taguée `#shorts` | Pas de Shorts |

L'application utilise uniquement l'API officielle **YouTube Data API v3** et le lecteur
officiel **YouTube IFrame Player API**. Elle ne télécharge jamais de flux vidéo et ne
contourne pas le lecteur, conformément aux conditions d'utilisation de YouTube.

## Prérequis

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
git clone https://github.com/VOTRE_UTILISATEUR/focus-tube.git
cd focus-tube
open Package.swift
```

Dans Xcode : `Product > Run` (⌘R). L'app se lance sans configuration supplémentaire.

## Compiler en ligne de commande

Un script produit un bundle universel prêt à distribuer :

```bash
./Scripts/build-app.sh 1.0.0
```

Sortie : `dist/FocusTube.app` et `dist/FocusTube-1.0.0-macOS.zip` (binaire arm64 + x86_64, signé ad hoc).

Vérifier le binaire :

```bash
lipo -info dist/FocusTube.app/Contents/MacOS/FocusTube
codesign --verify --verbose dist/FocusTube.app
```

## Installation

### Depuis une release GitHub

1. Téléchargez `FocusTube-1.0.0-macOS.zip` dans l'onglet Releases.
2. Décompressez et glissez `FocusTube.app` dans `/Applications`.
3. Premier lancement : clic droit → Ouvrir (l'app n'est pas notarisée) ou :
   ```bash
   xattr -cr /Applications/FocusTube.app
   ```
4. Collez votre clé YouTube Data API v3.

### Depuis les sources

Après compilation en ligne de commande :

```bash
open dist/FocusTube.app
# ou
cp -R dist/FocusTube.app /Applications/
```

## Utilisation

1. **Écran de configuration** (premier lancement) : collez votre clé API. Elle est testée immédiatement.
2. **Recherche** : tapez un sujet précis (« grammaire japonaise », « système solaire », « soudure à l'arc »). Seules les vidéos des catégories autorisées et de plus de 3 minutes sont affichées, en niveaux de gris.
3. **Lecture** : le lecteur YouTube officiel s'ouvre. Vitesses disponibles : 0,5× à 1,5×. En pause, les suggestions YouTube sont masquées par un voile sombre ; seule la barre de contrôle reste visible. À la fin : « Vidéo terminée », aucune lecture automatique.
4. **Quota** : suivi en bas de l'écran. Les recherches identiques (à 24 h) sont servies depuis le cache local (`~/Library/Application Support/FocusTube/search-cache.json`).

Menu ⚙️ : changer la clé API ou vider le cache.

## Personnaliser le filtre

Le cœur du filtrage est dans `Sources/FocusTube/Config/AllowedCategories.swift` :

```swift
static let ids: Set<String> = ["2", "19", "25", "26", "27", "28", "29"]
```

Ajoutez ou retirez un identifiant YouTube pour élargir ou restreindre le filtre. Autres réglages dans `AppConfig.swift` : durée minimale, vitesse max, TTL du cache.

## Confidentialité

- Aucune donnée ne quitte votre machine sauf les requêtes vers `www.googleapis.com/youtube/v3` (recherche) et `www.youtube.com` (lecture).
- La clé API est stockée uniquement dans le Trousseau macOS (`com.focustube.app`).
- Pas de télémétrie, pas de compte, pas de publicité.

## Licence

MIT — voir [LICENSE](LICENSE).
