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
