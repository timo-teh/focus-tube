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
