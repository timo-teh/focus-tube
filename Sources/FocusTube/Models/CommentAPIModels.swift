import Foundation

/// Réponses brutes de l'API YouTube Data v3 (commentThreads.list et comments.list).
struct CommentThreadListResponse: Decodable {
    let items: [CommentThreadItem]
    let nextPageToken: String?
}

struct CommentThreadItem: Decodable {
    struct Snippet: Decodable {
        let topLevelComment: CommentItem
        let totalReplyCount: Int?
    }
    struct Replies: Decodable {
        let comments: [CommentItem]
    }
    let id: String
    let snippet: Snippet
    let replies: Replies?
}

struct CommentListResponse: Decodable {
    let items: [CommentItem]
    let nextPageToken: String?
}

struct CommentItem: Decodable {
    struct Snippet: Decodable {
        let authorDisplayName: String?
        let textOriginal: String?
        let textDisplay: String?
        let publishedAt: String?
    }
    let id: String
    let snippet: Snippet
}

/// Enveloppe d'erreur renvoyée par Google (`{"error": {"errors": [{"reason": …}], "message": …}}`).
struct GoogleAPIErrorEnvelope: Decodable {
    struct Inner: Decodable {
        struct Detail: Decodable {
            let reason: String?
        }
        let errors: [Detail]?
        let message: String?
    }
    let error: Inner
}
