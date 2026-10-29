import Foundation

/// Lecture seule des commentaires (commentThreads.list et comments.list : 1 unité chacun).
final class CommentsService {

    enum CommentsError: LocalizedError, Equatable {
        case commentsDisabled
        case quotaExceeded
        case invalidAPIKey
        case videoNotFound
        case network(String)
        case unreadable
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .commentsDisabled:
                return "Les commentaires sont désactivés sur cette vidéo."
            case .quotaExceeded:
                return "Quota YouTube de la journée épuisé : les commentaires seront de nouveau disponibles après la remise à zéro (minuit, heure du Pacifique)."
            case .invalidAPIKey:
                return "Clé API refusée par YouTube."
            case .videoNotFound:
                return "Vidéo introuvable."
            case .network(let message):
                return "Connexion impossible : \(message)"
            case .unreadable:
                return "Impossible de lire la réponse de l'API."
            case .http(let code, let message):
                return "Erreur de l'API (HTTP \(code)) : \(message)"
            }
        }
    }

    struct ThreadsPage {
        let threads: [CommentThread]
        let nextPageToken: String?
    }

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Une page de commentaires de premier niveau (avec jusqu'à 5 réponses incluses par l'API).
    func threads(videoId: String, pageToken: String?, apiKey: String) async throws -> ThreadsPage {
        var query = [
            URLQueryItem(name: "part", value: "snippet,replies"),
            URLQueryItem(name: "videoId", value: videoId),
            URLQueryItem(name: "order", value: CommentsConfig.order),
            URLQueryItem(name: "maxResults", value: String(CommentsConfig.pageSize)),
            URLQueryItem(name: "textFormat", value: "plainText"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        let response: CommentThreadListResponse = try await perform(path: "commentThreads", query: query)
        return ThreadsPage(threads: response.items.map(CommentThread.init(item:)),
                           nextPageToken: response.nextPageToken)
    }

    /// Toutes les réponses d'un commentaire (jusqu'à 100).
    func replies(parentId: String, apiKey: String) async throws -> [Comment] {
        let query = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "parentId", value: parentId),
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "textFormat", value: "plainText"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        let response: CommentListResponse = try await perform(path: "comments", query: query)
        return response.items.map(Comment.init(item:)).sorted(by: Comment.chronological)
    }

    // MARK: - Réseau

    private func perform<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(path)")!
        components.queryItems = query
        guard let url = components.url else { throw CommentsError.unreadable }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw CommentsError.network(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw mapError(statusCode: status, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CommentsError.unreadable
        }
    }

    private func mapError(statusCode: Int, data: Data) -> CommentsError {
        let envelope = try? decoder.decode(GoogleAPIErrorEnvelope.self, from: data)
        let reasons = envelope?.error.errors?.compactMap(\.reason) ?? []
        let message = envelope?.error.message ?? "réponse inattendue"

        if reasons.contains("commentsDisabled") { return .commentsDisabled }
        if reasons.contains("quotaExceeded") || reasons.contains("dailyLimitExceeded") { return .quotaExceeded }
        if reasons.contains("videoNotFound") { return .videoNotFound }
        if message.localizedCaseInsensitiveContains("API key") || statusCode == 401 { return .invalidAPIKey }
        return .http(statusCode, message)
    }
}
