#!/usr/bin/env bash
# =============================================================================
#  setup-focus-tube.sh
#  Crée le projet Focus Tube complet, le compile, et (option --publish) le
#  publie sur GitHub avec une première release v1.0.0.
#
#  Usage :
#    ./setup-focus-tube.sh                       # crée + compile
#    GITHUB_USER=moi ./setup-focus-tube.sh --publish   # crée + compile + publie
#
#  Variables optionnelles :
#    PROJECT_DIR   dossier cible (défaut : ~/focus-tube)
#    GITHUB_USER   identifiant GitHub (remplace VOTRE_UTILISATEUR dans le README)
# =============================================================================
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$HOME/focus-tube}"
GITHUB_USER="${GITHUB_USER:-}"
PUBLISH="${1:-}"

echo "==> Vérification de Xcode…"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Erreur : Xcode n'est pas sélectionné. Lancez :"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -license accept"
  exit 1
fi

# Vérification assouplie pour Bionic : on autorise un dossier vide ou ne contenant que le script lui-même
if [[ -e "$PROJECT_DIR" ]]; then
  # Compte les fichiers autres que setup-focus-tube.sh
  remaining=$(ls -A "$PROJECT_DIR" 2>/dev/null | grep -v "^setup-focus-tube.sh$" || true)
  if [[ -n "$remaining" ]]; then
    echo "Erreur : $PROJECT_DIR existe déjà et n'est pas vide. Supprimez-le ou changez PROJECT_DIR."
    exit 1
  fi
fi

echo "==> Création de l'arborescence dans ${PROJECT_DIR}…"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
mkdir -p .github/workflows Resources Scripts
mkdir -p Sources/FocusTube/Config Sources/FocusTube/Models Sources/FocusTube/Services
mkdir -p Sources/FocusTube/ViewModels Sources/FocusTube/Player Sources/FocusTube/Views

echo "==> Écriture des fichiers…"

# -----------------------------------------------------------------------------
cat > Package.swift <<'__FT__'
// swift-tools-version:5.7
// Focus Tube — client YouTube minimaliste orienté apprentissage.
// Ce package s'ouvre directement dans Xcode (File > Open > Package.swift).

import PackageDescription

let package = Package(
    name: "FocusTube",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FocusTube", targets: ["FocusTube"])
    ],
    targets: [
        .executableTarget(
            name: "FocusTube",
            path: "Sources/FocusTube"
        )
    ]
)
__FT__

# -----------------------------------------------------------------------------
cat > Resources/Info.plist <<'__FT__'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>fr</string>
    <key>CFBundleExecutable</key>
    <string>FocusTube</string>
    <key>CFBundleIdentifier</key>
    <string>com.focustube.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Focus Tube</string>
    <key>CFBundleDisplayName</key>
    <string>Focus Tube</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__VERSION__</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.education</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Distribué sous licence MIT</string>
</dict>
</plist>
__FT__

# -----------------------------------------------------------------------------
cat > Scripts/build-app.sh <<'__FT__'
#!/usr/bin/env bash
# Compile Focus Tube en binaire universel (arm64 + x86_64), assemble le bundle
# FocusTube.app, le signe ad hoc et produit un .zip prêt pour GitHub Releases.
#
# Usage : ./Scripts/build-app.sh [version]
# Exemple : ./Scripts/build-app.sh 1.0.0

set -euo pipefail

APP_NAME="FocusTube"
VERSION="${1:-0.0.0}"
OUT_DIR="dist"

# Se placer à la racine du dépôt quel que soit l'endroit d'où le script est lancé.
cd "$(dirname "$0")/.."

echo "==> Compilation universelle (arm64 + x86_64) en mode release…"
swift build -c release --arch arm64 --arch x86_64 --product "$APP_NAME"

BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BINARY="$BIN_DIR/$APP_NAME"

if [[ ! -f "$BINARY" ]]; then
    echo "Erreur : binaire introuvable à $BINARY" >&2
    exit 1
fi

APP="$OUT_DIR/$APP_NAME.app"
echo "==> Assemblage du bundle $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signature ad hoc (sans compte développeur)…"
codesign --force --deep --sign - "$APP"

echo "==> Vérification des architectures :"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

ZIP_NAME="$APP_NAME-$VERSION-macOS.zip"
echo "==> Création de $OUT_DIR/$ZIP_NAME…"
(cd "$OUT_DIR" && rm -f "$ZIP_NAME" && ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME")

echo "==> Terminé : $OUT_DIR/$ZIP_NAME"
__FT__
chmod +x Scripts/build-app.sh

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/FocusTubeApp.swift <<'__FT__'
import SwiftUI

/// Point d'entrée de l'application.
/// Une seule fenêtre, pas de menu « Nouvelle fenêtre », pas de notifications.
@main
struct FocusTubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("Focus Tube") {
            RootView()
                .environmentObject(appViewModel)
        }
        .defaultSize(width: 1000, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            // Supprime « Nouvelle fenêtre » : une seule fenêtre, un seul sujet à la fois.
            CommandGroup(replacing: .newItem) { }
            // Pas de menu Aide (tout est dans le README).
            CommandGroup(replacing: .help) { }
        }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/AppDelegate.swift <<'__FT__'
import AppKit

/// Délégué AppKit minimal.
/// Nécessaire pour que l'app se comporte comme une vraie application
/// (icône dans le Dock, fenêtre au premier plan) même lorsqu'elle est lancée
/// depuis Xcode en tant qu'exécutable Swift Package.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apparence sombre forcée : l'interface est pensée en niveaux de gris.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Config/AllowedCategories.swift <<'__FT__'
import Foundation

/// Liste des catégories YouTube autorisées.
///
/// C'EST ICI QU'ON MODIFIE LE FILTRE.
/// Ajoutez ou retirez un identifiant dans `ids` pour changer ce que l'app accepte.
/// Toute vidéo dont `categoryId` n'est pas dans cette liste est exclue des résultats.
///
/// Référence des catégories YouTube (identifiants officiels de l'API Data v3) :
///
///  Autorisées par défaut
///   2  — Autos & Vehicles
///  19  — Travel & Events
///  25  — News & Politics
///  26  — Howto & Style
///  27  — Education
///  28  — Science & Technology
///  29  — Nonprofits & Activism
///
///  Exclues par défaut (divertissement)
///   1  — Film & Animation
///  10  — Music
///  15  — Pets & Animals
///  17  — Sports
///  20  — Gaming
///  22  — People & Blogs
///  23  — Comedy
///  24  — Entertainment
///  30 à 44 — Movies, Anime, Action/Adventure, Classics, Comedy, Documentary,
///            Drama, Family, Foreign, Horror, Sci-Fi/Fantasy, Thriller, Shorts,
///            Shows, Trailers
enum AllowedCategories {

    /// Identifiants de catégories acceptés.
    static let ids: Set<String> = [
        "2",   // Autos & Vehicles
        "19",  // Travel & Events
        "25",  // News & Politics
        "26",  // Howto & Style
        "27",  // Education
        "28",  // Science & Technology
        "29"   // Nonprofits & Activism
    ]

    /// Noms lisibles, utilisés uniquement pour l'affichage et le débogage.
    static let names: [String: String] = [
        "1": "Film & Animation",
        "2": "Autos & Vehicles",
        "10": "Music",
        "15": "Pets & Animals",
        "17": "Sports",
        "19": "Travel & Events",
        "20": "Gaming",
        "22": "People & Blogs",
        "23": "Comedy",
        "24": "Entertainment",
        "25": "News & Politics",
        "26": "Howto & Style",
        "27": "Education",
        "28": "Science & Technology",
        "29": "Nonprofits & Activism",
        "30": "Movies",
        "31": "Anime/Animation",
        "32": "Action/Adventure",
        "33": "Classics",
        "34": "Comedy",
        "35": "Documentary",
        "36": "Drama",
        "37": "Family",
        "38": "Foreign",
        "39": "Horror",
        "40": "Sci-Fi/Fantasy",
        "41": "Thriller",
        "42": "Shorts",
        "43": "Shows",
        "44": "Trailers"
    ]

    /// Nom lisible d'une catégorie (ou l'identifiant brut si inconnu).
    static func name(for id: String) -> String {
        names[id] ?? "Catégorie \(id)"
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Config/AppConfig.swift <<'__FT__'
import Foundation

/// Constantes de configuration de l'application.
/// Tout ce qui est « réglable » sans toucher à la logique se trouve ici.
enum AppConfig {

    // MARK: - Filtrage

    /// Durée maximale (en secondes) considérée comme un Short.
    /// Toute vidéo de cette durée ou moins est exclue (3 minutes = 180 s).
    static let shortsMaxDurationSeconds = 180

    /// Marqueurs textuels qui signalent un Short dans le titre ou la description.
    /// La comparaison est insensible à la casse.
    static let shortsMarkers: [String] = ["#shorts"]

    // MARK: - Lecteur

    /// Vitesse de lecture maximale autorisée.
    static let maxPlaybackRate: Double = 1.5

    /// Vitesses proposées dans l'interface.
    static let allowedPlaybackRates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5]

    // MARK: - API YouTube

    /// Nombre de résultats demandés à search.list (maximum 50).
    /// Le coût est de 100 unités quel que soit ce nombre : autant en demander 50.
    static let maxSearchResults = 50

    /// Quota quotidien par défaut d'un projet Google Cloud.
    static let dailyQuota = 10_000

    /// Coût d'un appel search.list.
    static let searchCost = 100

    /// Coût d'un appel videos.list.
    static let videosListCost = 1

    // MARK: - Cache

    /// Durée de validité d'un résultat de recherche en cache (24 h).
    static let cacheTTL: TimeInterval = 24 * 60 * 60

    /// Nombre maximal de recherches conservées sur disque.
    static let cacheMaxEntries = 200
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Models/Video.swift <<'__FT__'
import Foundation

/// Modèle d'une vidéo telle qu'affichée dans l'application.
/// Volontairement dépouillé : pas de vues, pas de likes, pas de date mise en avant.
struct Video: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let channelTitle: String
    let description: String
    let thumbnailURL: URL?
    let durationSeconds: Int
    let categoryId: String

    /// Durée formatée « 12:34 » ou « 1:05:20 ».
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Nom lisible de la catégorie.
    var categoryName: String {
        AllowedCategories.name(for: categoryId)
    }
}

extension Video {
    /// Construit une `Video` à partir d'un élément renvoyé par videos.list.
    /// Retourne `nil` si la durée est illisible.
    init?(item: VideoListItem) {
        guard let seconds = ISO8601Duration.seconds(from: item.contentDetails.duration) else {
            return nil
        }
        let thumbs = item.snippet.thumbnails ?? [:]
        let thumbString = thumbs["medium"]?.url ?? thumbs["high"]?.url ?? thumbs["default"]?.url

        self.id = item.id
        self.title = item.snippet.title
        self.channelTitle = item.snippet.channelTitle
        self.description = item.snippet.description
        self.thumbnailURL = thumbString.flatMap(URL.init(string:))
        self.durationSeconds = seconds
        self.categoryId = item.snippet.categoryId ?? ""
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Models/YouTubeAPIModels.swift <<'__FT__'
import Foundation

// Modèles de décodage des réponses de l'API YouTube Data v3.
// Seuls les champs réellement utilisés sont déclarés.

// MARK: - search.list

struct SearchListResponse: Decodable {
    let items: [SearchItem]

    struct SearchItem: Decodable {
        let id: ResourceID

        struct ResourceID: Decodable {
            let videoId: String?
        }
    }
}

// MARK: - videos.list

struct VideoListResponse: Decodable {
    let items: [VideoListItem]
}

struct VideoListItem: Decodable {
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails

    struct Snippet: Decodable {
        let title: String
        let description: String
        let channelTitle: String
        let categoryId: String?
        let thumbnails: [String: Thumbnail]?
    }

    struct Thumbnail: Decodable {
        let url: String
    }

    struct ContentDetails: Decodable {
        /// Durée au format ISO 8601, par exemple « PT12M34S ».
        let duration: String
    }
}

// MARK: - Erreurs

struct APIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let code: Int
        let message: String
        let errors: [Detail]?

        struct Detail: Decodable {
            let reason: String?
            let message: String?
        }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Models/ISO8601Duration.swift <<'__FT__'
import Foundation

/// Parseur minimal de durées ISO 8601 telles que renvoyées par YouTube.
/// Exemples : « PT4M13S », « PT1H2M3S », « PT45S », « P1DT2H », « P0D » (direct).
enum ISO8601Duration {

    /// Convertit une durée ISO 8601 en secondes. Retourne `nil` si le format est invalide.
    static func seconds(from iso: String) -> Int? {
        guard iso.hasPrefix("P") else { return nil }

        var total = 0
        var number = 0
        var inTimeSection = false

        for character in iso.dropFirst() {
            if let digit = character.wholeNumberValue {
                number = number * 10 + digit
                continue
            }

            switch character {
            case "T":
                inTimeSection = true
            case "Y":
                total += number * 365 * 86_400
            case "W":
                total += number * 7 * 86_400
            case "D":
                total += number * 86_400
            case "H":
                total += number * 3_600
            case "M":
                // « M » signifie mois avant le « T », minutes après.
                total += inTimeSection ? number * 60 : number * 30 * 86_400
            case "S":
                total += number
            default:
                return nil
            }
            number = 0
        }

        return total
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Services/KeychainService.swift <<'__FT__'
import Foundation
import Security

/// Stockage sécurisé de la clé API dans le Trousseau macOS.
/// La clé n'est jamais écrite dans un fichier ni dans UserDefaults.
struct KeychainService {

    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "code \(status)"
                return "Erreur du Trousseau : \(message)"
            }
        }
    }

    private let service = "com.focustube.app"
    private let account = "youtube-data-api-key"

    /// Lit la clé API. Retourne `nil` si elle n'existe pas.
    func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Enregistre (ou met à jour) la clé API.
    func save(_ value: String) throws {
        let data = Data(value.utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrLabel as String] = "Focus Tube — clé YouTube Data API"
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Supprime la clé API du Trousseau.
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Services/YouTubeAPIService.swift <<'__FT__'
import Foundation

/// Erreurs renvoyées par le client API, avec messages prêts à afficher.
enum YouTubeAPIError: LocalizedError {
    case invalidAPIKey
    case quotaExceeded
    case apiNotEnabled
    case network(Error)
    case server(code: Int, message: String)
    case invalidResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "La clé API n'est pas valide. Vérifiez-la dans la Google Cloud Console."
        case .quotaExceeded:
            return "Le quota quotidien de l'API YouTube (10 000 unités) est dépassé. "
                + "Il se réinitialise chaque jour à minuit, heure du Pacifique (vers 9 h à Paris). "
                + "Les recherches déjà en cache restent disponibles."
        case .apiNotEnabled:
            return "L'API YouTube Data v3 n'est pas activée pour ce projet Google Cloud."
        case .network(let error):
            return "Problème de connexion : \(error.localizedDescription)"
        case .server(let code, let message):
            return "Erreur de l'API YouTube (\(code)) : \(message)"
        case .invalidResponse:
            return "Réponse inattendue du serveur."
        case .decoding:
            return "Impossible de lire la réponse de l'API."
        }
    }
}

/// Client minimal de l'API YouTube Data v3.
/// Deux appels seulement : search.list (100 unités) et videos.list (1 unité).
/// Aucun flux vidéo n'est jamais téléchargé : seules les métadonnées transitent ici.
final class YouTubeAPIService {

    private let session: URLSession
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Appels publics

    /// Recherche des identifiants de vidéos pour une requête. Coût : 100 unités.
    func searchVideoIds(query: String, apiKey: String) async throws -> [String] {
        var components = URLComponents(string: baseURL + "/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "id"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "safeSearch", value: "moderate"),
            URLQueryItem(name: "maxResults", value: String(AppConfig.maxSearchResults)),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let response: SearchListResponse = try await perform(url: components.url!)
        return response.items.compactMap { $0.id.videoId }
    }

    /// Récupère catégorie, durée et métadonnées pour jusqu'à 50 vidéos. Coût : 1 unité.
    func videoDetails(ids: [String], apiKey: String) async throws -> [VideoListItem] {
        guard !ids.isEmpty else { return [] }

        var components = URLComponents(string: baseURL + "/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "id", value: ids.prefix(50).joined(separator: ",")),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let response: VideoListResponse = try await perform(url: components.url!)
        return response.items
    }

    /// Vérifie qu'une clé fonctionne avec un appel à 1 unité (videos.list sur une vidéo connue).
    func validate(apiKey: String) async throws {
        var components = URLComponents(string: baseURL + "/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "id"),
            URLQueryItem(name: "id", value: "jNQXAC9IVRw"), // « Me at the zoo », première vidéo YouTube
            URLQueryItem(name: "key", value: apiKey)
        ]
        let _: VideoListResponse = try await perform(url: components.url!)
    }

    // MARK: - Interne

    private func perform<T: Decodable>(url: URL) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw YouTubeAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw YouTubeAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw mapError(statusCode: http.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YouTubeAPIError.decoding
        }
    }

    /// Traduit une réponse d'erreur Google en `YouTubeAPIError` compréhensible.
    private func mapError(statusCode: Int, data: Data) -> YouTubeAPIError {
        guard let apiError = try? decoder.decode(APIErrorResponse.self, from: data) else {
            return .server(code: statusCode, message: "Réponse illisible")
        }

        let reasons = Set((apiError.error.errors ?? []).compactMap { $0.reason })
        let message = apiError.error.message

        if reasons.contains("quotaExceeded") || reasons.contains("dailyLimitExceeded")
            || reasons.contains("rateLimitExceeded") {
            return .quotaExceeded
        }

        if reasons.contains("keyInvalid")
            || (reasons.contains("badRequest") && message.localizedCaseInsensitiveContains("API key"))
            || message.localizedCaseInsensitiveContains("API key not valid") {
            return .invalidAPIKey
        }

        if reasons.contains("accessNotConfigured") {
            return .apiNotEnabled
        }

        if statusCode == 403 && reasons.contains("forbidden") {
            return .invalidAPIKey
        }

        return .server(code: statusCode, message: message)
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Services/SearchCache.swift <<'__FT__'
import Foundation

/// Cache des résultats de recherche, en mémoire et sur disque.
/// Objectif : ne pas dépenser 101 unités de quota pour une recherche déjà faite.
/// Fichier : ~/Library/Application Support/FocusTube/search-cache.json
final class SearchCache {

    private struct Entry: Codable {
        let date: Date
        let videos: [Video]
    }

    private var entries: [String: Entry] = [:]
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.focustube.cache", qos: .utility)

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent("FocusTube", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("search-cache.json")
        load()
    }

    /// Normalise une requête pour que « Python  débutant » et « python débutant » partagent le même cache.
    private func key(for query: String) -> String {
        query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Retourne les vidéos en cache si l'entrée existe et n'a pas expiré.
    func videos(for query: String) -> [Video]? {
        let k = key(for: query)
        guard let entry = entries[k] else { return nil }
        guard Date().timeIntervalSince(entry.date) < AppConfig.cacheTTL else {
            entries.removeValue(forKey: k)
            return nil
        }
        return entry.videos
    }

    /// Enregistre un résultat (même vide : une recherche sans résultat ne doit pas être refaite).
    func store(_ videos: [Video], for query: String) {
        entries[key(for: query)] = Entry(date: Date(), videos: videos)
        prune()
        save()
    }

    /// Vide complètement le cache.
    func clear() {
        entries.removeAll()
        save()
    }

    var count: Int { entries.count }

    // MARK: - Persistance

    private func prune() {
        guard entries.count > AppConfig.cacheMaxEntries else { return }
        let sorted = entries.sorted { $0.value.date > $1.value.date }
        entries = Dictionary(uniqueKeysWithValues: sorted.prefix(AppConfig.cacheMaxEntries).map { ($0.key, $0.value) })
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        let snapshot = entries
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Services/QuotaTracker.swift <<'__FT__'
import Foundation
import Combine

/// Estimation locale de la consommation du quota YouTube.
/// Google ne fournit pas le compteur en temps réel : on additionne les coûts connus
/// (100 par recherche, 1 par videos.list) et on remet à zéro à minuit, heure du Pacifique,
/// comme le fait Google.
@MainActor
final class QuotaTracker: ObservableObject {

    @Published private(set) var usedToday: Int = 0

    private let defaults = UserDefaults.standard
    private let dayKey = "quota.day"
    private let usedKey = "quota.used"

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init() {
        refresh()
    }

    private var todayKey: String {
        dayFormatter.string(from: Date())
    }

    /// Remet le compteur à zéro si le jour (Pacifique) a changé.
    func refresh() {
        if defaults.string(forKey: dayKey) != todayKey {
            defaults.set(todayKey, forKey: dayKey)
            defaults.set(0, forKey: usedKey)
        }
        usedToday = defaults.integer(forKey: usedKey)
    }

    /// Enregistre une dépense d'unités.
    func record(_ units: Int) {
        refresh()
        usedToday += units
        defaults.set(usedToday, forKey: usedKey)
    }

    var remaining: Int {
        max(0, AppConfig.dailyQuota - usedToday)
    }

    /// Nombre de recherches restantes (chaque recherche coûte search + videos.list).
    var searchesRemaining: Int {
        remaining / (AppConfig.searchCost + AppConfig.videosListCost)
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Services/ContentFilter.swift <<'__FT__'
import Foundation

/// Règles d'exclusion du divertissement et des Shorts.
/// Une vidéo est gardée uniquement si elle passe les trois tests.
enum ContentFilter {

    static func isAllowed(_ video: Video) -> Bool {
        isAllowedCategory(video) && isNotShort(video) && hasNoShortsMarker(video)
    }

    /// 1. La catégorie doit figurer dans `AllowedCategories.ids`.
    static func isAllowedCategory(_ video: Video) -> Bool {
        AllowedCategories.ids.contains(video.categoryId)
    }

    /// 2. Durée strictement supérieure à 3 minutes.
    ///    Les directs (durée « P0D » = 0 s) sont donc exclus aussi.
    static func isNotShort(_ video: Video) -> Bool {
        video.durationSeconds > AppConfig.shortsMaxDurationSeconds
    }

    /// 3. Ni le titre ni la description ne contiennent « #shorts ».
    static func hasNoShortsMarker(_ video: Video) -> Bool {
        let haystack = (video.title + " " + video.description).lowercased()
        return !AppConfig.shortsMarkers.contains { haystack.contains($0.lowercased()) }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/ViewModels/AppViewModel.swift <<'__FT__'
import Foundation
import Combine

/// ViewModel racine : navigation entre les écrans et gestion de la clé API.
@MainActor
final class AppViewModel: ObservableObject {

    /// Les trois écrans de l'application. Pas de page d'accueil, pas de fil.
    enum Screen: Equatable {
        case setup
        case search
        case player(Video)
    }

    @Published private(set) var screen: Screen
    @Published private(set) var apiKey: String?

    let api = YouTubeAPIService()
    let cache = SearchCache()
    let quota = QuotaTracker()
    let searchViewModel: SearchViewModel

    private let keychain = KeychainService()

    init() {
        let storedKey = keychain.read()
        apiKey = storedKey
        screen = storedKey == nil ? .setup : .search
        searchViewModel = SearchViewModel(api: api, cache: cache, quota: quota)
        searchViewModel.apiKeyProvider = { [weak self] in self?.apiKey }
    }

    // MARK: - Clé API

    /// Teste la clé (1 unité), puis l'enregistre dans le Trousseau.
    func validateAndSave(apiKey candidate: String) async throws {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw YouTubeAPIError.invalidAPIKey }

        try await api.validate(apiKey: trimmed)
        quota.record(AppConfig.videosListCost)
        try keychain.save(trimmed)

        apiKey = trimmed
        screen = .search
    }

    /// Supprime la clé et renvoie à l'écran de configuration.
    func resetAPIKey() {
        try? keychain.delete()
        apiKey = nil
        searchViewModel.reset()
        screen = .setup
    }

    // MARK: - Navigation

    func open(_ video: Video) {
        screen = .player(video)
    }

    func showSearch() {
        screen = .search
    }

    func clearCache() {
        cache.clear()
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/ViewModels/SearchViewModel.swift <<'__FT__'
import Foundation
import Combine

/// ViewModel de l'écran de recherche.
/// Enchaîne search.list → videos.list → filtrage → cache.
@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query: String = ""
    @Published private(set) var results: [Video] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasSearched = false
    @Published private(set) var servedFromCache = false
    @Published private(set) var lastQuery: String = ""

    /// Fournie par `AppViewModel` ; évite de dupliquer la clé ici.
    var apiKeyProvider: () -> String? = { nil }

    /// Suivi du quota, exposé à la vue via `quotaForDisplay`.
    let quotaTracker: QuotaTracker

    private let api: YouTubeAPIService
    private let cache: SearchCache
    private var quota: QuotaTracker { quotaTracker }

    init(api: YouTubeAPIService, cache: SearchCache, quota: QuotaTracker) {
        self.api = api
        self.cache = cache
        self.quotaTracker = quota
    }

    /// Lance une recherche. Ne consomme du quota que si le résultat n'est pas en cache.
    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        guard let apiKey = apiKeyProvider() else {
            errorMessage = "Aucune clé API enregistrée."
            return
        }

        isLoading = true
        errorMessage = nil
        hasSearched = true
        lastQuery = trimmed
        defer { isLoading = false }

        // 1. Cache
        if let cached = cache.videos(for: trimmed) {
            results = cached
            servedFromCache = true
            return
        }
        servedFromCache = false

        // 2. API
        do {
            let ids = try await api.searchVideoIds(query: trimmed, apiKey: apiKey)
            quota.record(AppConfig.searchCost)

            let items = try await api.videoDetails(ids: ids, apiKey: apiKey)
            quota.record(AppConfig.videosListCost)

            // 3. Filtrage : catégories, durée, #shorts
            let videos = items
                .compactMap(Video.init(item:))
                .filter(ContentFilter.isAllowed)

            // 4. Cache (y compris les résultats vides)
            cache.store(videos, for: trimmed)
            results = videos
        } catch let error as YouTubeAPIError {
            results = []
            errorMessage = error.errorDescription
        } catch {
            results = []
            errorMessage = "Erreur inattendue : \(error.localizedDescription)"
        }
    }

    /// Réinitialise l'état (changement de clé API).
    func reset() {
        query = ""
        results = []
        errorMessage = nil
        hasSearched = false
        servedFromCache = false
        lastQuery = ""
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/ViewModels/SearchViewModel+Quota.swift <<'__FT__'
import Foundation

extension SearchViewModel {
    /// Expose le suivi du quota à la vue, sans dupliquer l'état.
    var quotaForDisplay: QuotaTracker { quotaTracker }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/ViewModels/PlayerViewModel.swift <<'__FT__'
import Foundation
import Combine

/// ViewModel du lecteur.
/// Reçoit les événements du lecteur IFrame (via JavaScript) et lui envoie des commandes.
@MainActor
final class PlayerViewModel: ObservableObject {

    enum PlaybackState: Equatable {
        case loading
        case playing
        case paused
        case buffering
        case ended
        case error(String)
    }

    let video: Video

    @Published private(set) var state: PlaybackState = .loading
    @Published private(set) var playbackRate: Double = 1.0
    @Published private(set) var showPauseOverlay = false

    /// Exécute du JavaScript dans la WKWebView. Injecté par `YouTubePlayerWebView`.
    var jsExecutor: ((String) -> Void)?

    private var pauseOverlayTask: Task<Void, Never>?

    init(video: Video) {
        self.video = video
    }

    // MARK: - Événements venant du JavaScript

    /// Message reçu du lecteur : `{ event: String, data: Any? }`.
    func handle(message: [String: Any]) {
        guard let event = message["event"] as? String else { return }

        switch event {
        case "ready":
            state = .buffering

        case "stateChange":
            guard let code = message["data"] as? Int else { return }
            updateState(fromYouTubeCode: code)

        case "rateChange":
            guard let rate = message["data"] as? Double else { return }
            enforceRateLimit(rate)

        case "error":
            let code = message["data"] as? Int ?? -1
            state = .error(errorMessage(forCode: code))

        default:
            break
        }
    }

    /// Codes de l'IFrame API : -1 non démarré, 0 terminé, 1 lecture, 2 pause, 3 chargement, 5 en file.
    private func updateState(fromYouTubeCode code: Int) {
        switch code {
        case 0: state = .ended
        case 1: state = .playing
        case 2: state = .paused
        case 3: state = .buffering
        default: state = .loading
        }
        schedulePauseOverlay()
    }

    /// Affiche la surcouche de pause avec un léger délai, pour éviter un clignotement
    /// lors d'un simple déplacement dans la barre de progression.
    private func schedulePauseOverlay() {
        pauseOverlayTask?.cancel()
        guard state == .paused else {
            showPauseOverlay = false
            return
        }
        pauseOverlayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, let self, self.state == .paused else { return }
            self.showPauseOverlay = true
        }
    }

    /// Règle n° 5 : jamais au-dessus de 1,5×.
    private func enforceRateLimit(_ rate: Double) {
        if rate > AppConfig.maxPlaybackRate {
            jsExecutor?("ftSetRate(\(AppConfig.maxPlaybackRate));")
            playbackRate = AppConfig.maxPlaybackRate
        } else {
            playbackRate = rate
        }
    }

    private func errorMessage(forCode code: Int) -> String {
        switch code {
        case 2: return "Identifiant de vidéo invalide."
        case 5: return "Le lecteur HTML5 a rencontré une erreur."
        case 100: return "Cette vidéo est introuvable ou privée."
        case 101, 150: return "L'auteur n'autorise pas la lecture de cette vidéo en dehors de YouTube."
        default: return "Erreur de lecture (code \(code))."
        }
    }

    // MARK: - Commandes vers le lecteur

    func play() {
        jsExecutor?("ftPlay();")
    }

    func pause() {
        jsExecutor?("ftPause();")
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(rate, AppConfig.maxPlaybackRate)
        guard clamped != playbackRate else { return }
        playbackRate = clamped
        jsExecutor?("ftSetRate(\(clamped));")
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Player/PlayerHTML.swift <<'__FT__'
import Foundation

/// Page HTML minimale qui charge le lecteur officiel YouTube IFrame Player API.
/// Elle est intégrée au binaire (pas de fichier de ressources à embarquer).
///
/// Conformité : le flux vidéo est lu exclusivement par le lecteur officiel YouTube ;
/// l'application ne télécharge rien et ne contourne aucun mécanisme du lecteur.
enum PlayerHTML {

    /// Nom du canal de messages JavaScript → Swift.
    static let messageHandlerName = "focusTube"

    /// Génère la page pour une vidéo donnée.
    static func render(videoId: String) -> String {
        // Un identifiant YouTube ne contient que [A-Za-z0-9_-] : on neutralise tout le reste.
        let safeId = videoId.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let maxRate = AppConfig.maxPlaybackRate

        return """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            html, body {
                margin: 0; padding: 0;
                width: 100%; height: 100%;
                background: #000; overflow: hidden;
            }
            #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
            var MAX_RATE = \(maxRate);
            var VIDEO_ID = "\(safeId)";
            var player = null;

            // Envoi d'un événement vers Swift.
            function post(event, data) {
                try {
                    window.webkit.messageHandlers.\(messageHandlerName).postMessage({
                        event: event,
                        data: (data === undefined) ? null : data
                    });
                } catch (e) { /* hors WKWebView : ignoré */ }
            }

            // Commandes appelées depuis Swift.
            function ftPlay()        { if (player && player.playVideo)       { player.playVideo(); } }
            function ftPause()       { if (player && player.pauseVideo)      { player.pauseVideo(); } }
            function ftStop()        { if (player && player.stopVideo)       { player.stopVideo(); } }
            function ftSetRate(r)    { if (player && player.setPlaybackRate) { player.setPlaybackRate(Math.min(r, MAX_RATE)); } }

            // Chargement de l'API officielle.
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    videoId: VIDEO_ID,
                    playerVars: {
                        rel: 0,                // suggestions limitées à la chaîne (et masquées par l'app)
                        modestbranding: 1,     // logo YouTube discret
                        iv_load_policy: 3,     // pas d'annotations
                        autoplay: 1,
                        controls: 1,
                        fs: 1,
                        playsinline: 1,
                        enablejsapi: 1,
                        origin: 'https://www.youtube.com'
                    },
                    events: {
                        'onReady': onPlayerReady,
                        'onStateChange': onPlayerStateChange,
                        'onPlaybackRateChange': onPlaybackRateChange,
                        'onError': onPlayerError
                    }
                });
            }

            function onPlayerReady(event) {
                event.target.setPlaybackRate(1);
                post('ready', null);
                event.target.playVideo();
            }

            function onPlayerStateChange(event) {
                post('stateChange', event.data);
            }

            // Règle : vitesse plafonnée à MAX_RATE, corrigée immédiatement côté JS.
            function onPlaybackRateChange(event) {
                var rate = event.data;
                if (rate > MAX_RATE) {
                    player.setPlaybackRate(MAX_RATE);
                    rate = MAX_RATE;
                }
                post('rateChange', rate);
            }

            function onPlayerError(event) {
                post('error', event.data);
            }
        </script>
        </body>
        </html>
        """
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Player/YouTubePlayerWebView.swift <<'__FT__'
import SwiftUI
import WebKit

/// Encapsule une WKWebView contenant le lecteur YouTube IFrame.
///
/// Garde-fous :
/// - toute navigation du cadre principal hors de la page initiale est annulée ;
/// - toute ouverture de nouvelle fenêtre (clic sur le logo ou le titre YouTube) est bloquée ;
/// - les événements du lecteur remontent vers `PlayerViewModel`.
struct YouTubePlayerWebView: NSViewRepresentable {

    @ObservedObject var viewModel: PlayerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.userContentController.add(context.coordinator, name: PlayerHTML.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.underPageBackgroundColor = .black

        // Canal Swift → JavaScript.
        viewModel.jsExecutor = { [weak webView] script in
            webView?.evaluateJavaScript(script) { _, _ in }
        }

        // Le baseURL youtube.com est requis par l'IFrame API pour accepter l'intégration.
        let html = PlayerHTML.render(videoId: viewModel.video.id)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Rien à mettre à jour : une vue = une vidéo (voir `.id(video.id)` dans RootView).
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.evaluateJavaScript("ftStop();") { _, _ in }
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: PlayerHTML.messageHandlerName)
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
        nsView.loadHTMLString("", baseURL: nil)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

        private let viewModel: PlayerViewModel
        private var initialLoadAllowed = true

        init(viewModel: PlayerViewModel) {
            self.viewModel = viewModel
        }

        // JavaScript → Swift
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == PlayerHTML.messageHandlerName,
                  let body = message.body as? [String: Any] else { return }
            Task { @MainActor in
                viewModel.handle(message: body)
            }
        }

        // Navigation : n'autoriser que le chargement initial dans le cadre principal.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            // Pas de cadre cible = demande d'ouverture dans une nouvelle fenêtre : refusée.
            guard let targetFrame = navigationAction.targetFrame else {
                decisionHandler(.cancel)
                return
            }

            // Sous-cadres (l'iframe du lecteur lui-même) : autorisés.
            guard targetFrame.isMainFrame else {
                decisionHandler(.allow)
                return
            }

            // Cadre principal : seul le premier chargement (notre HTML) passe.
            if initialLoadAllowed {
                initialLoadAllowed = false
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        // Bloque les fenêtres surgissantes (target="_blank" vers youtube.com).
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Views/Theme.swift <<'__FT__'
import SwiftUI

/// Palette en niveaux de gris. Aucune couleur saturée dans l'interface :
/// seule la vidéo en lecture est en couleur.
enum Theme {
    static let background = Color(white: 0.09)
    static let surface = Color(white: 0.15)
    static let surfaceHover = Color(white: 0.20)
    static let border = Color(white: 0.28)
    static let textPrimary = Color(white: 0.93)
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.45)
}

/// Bouton monochrome. `prominent` inverse les tons pour l'action principale.
struct MonoButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(prominent ? Theme.textPrimary : Theme.surface)
            .foregroundColor(prominent ? Theme.background : Theme.textPrimary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.border, lineWidth: prominent ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Champ de texte sobre, sans bordure système.
struct MonoFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.title3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func monoField() -> some View {
        modifier(MonoFieldModifier())
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Views/RootView.swift <<'__FT__'
import SwiftUI

/// Aiguillage entre les trois écrans. Applique le thème global.
struct RootView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        Group {
            switch app.screen {
            case .setup:
                APIKeySetupView()
            case .search:
                SearchView(viewModel: app.searchViewModel)
            case .player(let video):
                // `.id` garantit un lecteur neuf à chaque vidéo.
                PlayerView(video: video)
                    .id(video.id)
            }
        }
        .frame(minWidth: 820, minHeight: 580)
        .background(Theme.background)
        .foregroundColor(Theme.textPrimary)
        .preferredColorScheme(.dark)
        .tint(Color(white: 0.7))
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Views/APIKeySetupView.swift <<'__FT__'
import SwiftUI

/// Premier lancement : saisie de la clé YouTube Data API.
/// La clé est testée (1 unité) puis enregistrée dans le Trousseau.
struct APIKeySetupView: View {
    @EnvironmentObject private var app: AppViewModel

    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Text("Focus Tube")
                .font(.system(size: 34, weight: .semibold))

            Text("Un client YouTube sans recommandations, sans Shorts et sans divertissement. "
                 + "Pour commencer, l'application a besoin de votre propre clé YouTube Data API v3.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Comment obtenir une clé")
                    .font(.headline)
                Text("1. Ouvrez la Google Cloud Console et créez un projet.\n"
                     + "2. Dans « API et services » › « Bibliothèque », activez YouTube Data API v3.\n"
                     + "3. Dans « Identifiants », créez une clé API et collez-la ci-dessous.\n"
                     + "Le guide détaillé se trouve dans le README du projet.")
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Ouvrir la Google Cloud Console", destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!)
                    .font(.callout)
                    .foregroundColor(Theme.textPrimary)
                    .underline()
            }

            SecureField("Clé API YouTube Data v3", text: $apiKey)
                .monoField()
                .onSubmit { submit() }
                .disabled(isValidating)

            HStack(spacing: 12) {
                Button(action: submit) {
                    HStack(spacing: 8) {
                        if isValidating {
                            ProgressView().controlSize(.small)
                        }
                        Text(isValidating ? "Vérification…" : "Enregistrer la clé")
                    }
                }
                .buttonStyle(MonoButtonStyle(prominent: true))
                .disabled(isValidating || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)

                Text("Stockée uniquement dans le Trousseau macOS.")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(6)
            }

            Spacer()
            Spacer()
        }
        .padding(48)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        guard !isValidating else { return }
        isValidating = true
        errorMessage = nil
        Task {
            do {
                try await app.validateAndSave(apiKey: apiKey)
            } catch {
                errorMessage = error.localizedDescription
            }
            isValidating = false
        }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Views/SearchView.swift <<'__FT__'
import SwiftUI

/// Écran principal : une barre de recherche, et rien d'autre tant qu'on n'a pas cherché.
struct SearchView: View {
    @EnvironmentObject private var app: AppViewModel
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject private var quota: QuotaTracker

    @FocusState private var searchFieldFocused: Bool

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        _quota = ObservedObject(wrappedValue: viewModel.quotaForDisplay)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            content
            Divider().overlay(Theme.border)
            footer
        }
        .onAppear { searchFieldFocused = !viewModel.hasSearched }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Focus Tube")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                settingsMenu
            }

            HStack(spacing: 10) {
                TextField("Quel sujet voulez-vous apprendre ?", text: $viewModel.query)
                    .monoField()
                    .focused($searchFieldFocused)
                    .onSubmit { runSearch() }
                    .disabled(viewModel.isLoading)

                Button("Rechercher") { runSearch() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
                    .disabled(viewModel.isLoading || viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var settingsMenu: some View {
        Menu {
            Button("Changer la clé API…") { app.resetAPIKey() }
            Button("Vider le cache des recherches") { app.clearCache() }
        } label: {
            Image(systemName: "gearshape")
                .foregroundColor(Theme.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            centered {
                ProgressView()
                Text("Recherche en cours…")
                    .foregroundColor(Theme.textSecondary)
            }
        } else if let error = viewModel.errorMessage {
            centered {
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: 520)
            }
        } else if !viewModel.hasSearched {
            centered {
                Text("Aucune recommandation ici.")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                Text("Cherchez un sujet précis pour commencer.")
                    .foregroundColor(Theme.textTertiary)
            }
        } else if viewModel.results.isEmpty {
            centered {
                Text("Aucun contenu éducatif trouvé pour cette recherche.")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                Text("Essayez des termes plus précis ou une autre formulation.")
                    .foregroundColor(Theme.textTertiary)
            }
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(viewModel.results.count) vidéo(s) pour « \(viewModel.lastQuery) »")
                    if viewModel.servedFromCache {
                        Text("· résultat en cache, quota non consommé")
                    }
                }
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 6)

                ForEach(viewModel.results) { video in
                    VideoRowView(video: video) {
                        app.open(video)
                    }
                    Divider().overlay(Theme.border.opacity(0.5))
                        .padding(.horizontal, 28)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Pied de page

    private var footer: some View {
        HStack {
            Text("Quota estimé aujourd'hui : \(quota.usedToday) / \(AppConfig.dailyQuota) unités")
            Text("· environ \(quota.searchesRemaining) recherche(s) restante(s)")
            Spacer()
            Text("Remise à zéro vers 9 h (heure de Paris)")
        }
        .font(.caption)
        .foregroundColor(Theme.textTertiary)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
    }

    private func runSearch() {
        Task { await viewModel.search() }
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Views/VideoRowView.swift <<'__FT__'
import SwiftUI

/// Ligne de résultat : miniature en niveaux de gris, titre, chaîne, durée.
/// Pas de vues, pas de likes, pas de date, pas de badge.
struct VideoRowView: View {
    let video: Video
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(video.formattedDuration) · \(video.categoryName)")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(isHovered ? Theme.surface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    /// Miniature forcée en niveaux de gris (règle n° 6).
    private var thumbnail: some View {
        ZStack {
            Theme.surface
            if let url = video.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.clear
                    }
                }
            }
        }
        .frame(width: 168, height: 94)
        .clipped()
        .cornerRadius(4)
        .saturation(0)
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > Sources/FocusTube/Views/PlayerView.swift <<'__FT__'
import SwiftUI

/// Écran de lecture : la vidéo (seule chose en couleur), la vitesse, le titre,
/// la chaîne et la description. Aucune suggestion, aucun commentaire.
struct PlayerView: View {
    @EnvironmentObject private var app: AppViewModel
    @StateObject private var viewModel: PlayerViewModel

    init(video: Video) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(video: video))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    player
                    rateSelector
                    metadata
                }
                .padding(28)
            }
        }
    }

    // MARK: - Barre supérieure

    private var toolbar: some View {
        HStack {
            Button {
                app.showSearch()
            } label: {
                Label("Nouvelle recherche", systemImage: "chevron.left")
            }
            .buttonStyle(MonoButtonStyle())
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    // MARK: - Lecteur et surcouches

    private var player: some View {
        ZStack {
            YouTubePlayerWebView(viewModel: viewModel)

            if viewModel.showPauseOverlay {
                pauseOverlay
            }

            if viewModel.state == .ended {
                endedOverlay
            }

            if case .error(let message) = viewModel.state {
                errorOverlay(message)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: 1100)
        .background(Color.black)
        .cornerRadius(6)
        .frame(maxWidth: .infinity)
    }

    /// Pendant la pause, YouTube affiche des suggestions au centre du lecteur.
    /// On les masque en laissant la barre de contrôle (en bas) accessible.
    private var pauseOverlay: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.opacity(0.96)
                VStack(spacing: 12) {
                    Text("En pause")
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                    Button("Reprendre") { viewModel.play() }
                        .buttonStyle(MonoButtonStyle(prominent: true))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.play() }

            Color.clear.frame(height: 56) // zone des contrôles YouTube
        }
    }

    /// Fin de vidéo : écran de fin masqué, aucune lecture automatique.
    private var endedOverlay: some View {
        ZStack {
            Color.black
            VStack(spacing: 16) {
                Text("Vidéo terminée")
                    .font(.title)
                    .foregroundColor(Theme.textPrimary)
                Button("Nouvelle recherche") { app.showSearch() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
            }
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        ZStack {
            Color.black
            VStack(spacing: 16) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: 420)
                Button("Nouvelle recherche") { app.showSearch() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
            }
        }
    }

    // MARK: - Vitesse

    /// Sélecteur monochrome. Les vitesses viennent de `AppConfig.allowedPlaybackRates`.
    private var rateSelector: some View {
        HStack(spacing: 8) {
            Text("Vitesse")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)

            ForEach(AppConfig.allowedPlaybackRates, id: \.self) { rate in
                let selected = abs(viewModel.playbackRate - rate) < 0.001
                Button("\(rate.formatted())×") {
                    viewModel.setPlaybackRate(rate)
                }
                .buttonStyle(MonoButtonStyle(prominent: selected))
                .font(.caption)
            }

            Text("maximum \(AppConfig.maxPlaybackRate.formatted())×")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - Métadonnées

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.video.title)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Text(viewModel.video.channelTitle)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            Divider().overlay(Theme.border)

            Text(viewModel.video.description.isEmpty ? "Aucune description." : viewModel.video.description)
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: 1100, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
__FT__

# -----------------------------------------------------------------------------
cat > .gitignore <<'__FT__'
# Xcode
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
xcuserdata/
*.xccheckout
*.moved-aside
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/
Package.resolved
*.xcodeproj

# Sorties de build
dist/
*.app
*.zip
*.dmg

# macOS
.DS_Store
._*
.Spotlight-V100
.Trashes

# Divers
*.log
*.orig
__FT__

# -----------------------------------------------------------------------------
cat > LICENSE <<'__FT__'
MIT License

Copyright (c) 2026 Focus Tube contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
__FT__

# -----------------------------------------------------------------------------
cat > .github/workflows/release.yml <<'__FT__'
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  build-and-release:
    name: Compiler et publier Focus Tube
    runs-on: macos-14

    steps:
      - name: Récupérer le code
        uses: actions/checkout@v4

      - name: Afficher les versions des outils
        run: |
          sw_vers
          xcodebuild -version
          swift --version

      - name: Compiler le bundle universel
        run: |
          VERSION="${GITHUB_REF_NAME#v}"
          chmod +x Scripts/build-app.sh
          ./Scripts/build-app.sh "$VERSION"

      - name: Publier dans GitHub Releases
        uses: softprops/action-gh-release@v2
        with:
          files: dist/*.zip
          generate_release_notes: true
          body: |
            ## Installation
            1. Téléchargez le fichier `.zip` ci-dessous et décompressez-le.
            2. Glissez `FocusTube.app` dans `/Applications`.
            3. Au premier lancement, faites **clic droit › Ouvrir** (l'application n'est pas notarisée),
               ou exécutez `xattr -cr /Applications/FocusTube.app` dans le Terminal.
            4. Saisissez votre clé YouTube Data API v3 (voir le README).
__FT__

# -----------------------------------------------------------------------------
cat > README.md <<'__FT__'
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
