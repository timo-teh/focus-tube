import Foundation

/// Un commentaire tel qu'affiché : auteur, date, texte. Aucun compteur (« J'aime », réponses…).
struct Comment: Identifiable, Equatable {
    let id: String
    let author: String
    let text: String
    let publishedAt: Date?
}

/// Un commentaire de premier niveau et ses réponses.
struct CommentThread: Identifiable, Equatable {
    let id: String
    let comment: Comment
    var replies: [Comment]
    /// Utilisé uniquement pour savoir s'il reste des réponses à charger ; jamais affiché.
    let totalReplyCount: Int
    var allRepliesLoaded: Bool

    var hasReplies: Bool { totalReplyCount > 0 || !replies.isEmpty }
    var hasUnloadedReplies: Bool { !allRepliesLoaded && totalReplyCount > replies.count }
}

enum CommentDates {
    private static let strict: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .full
        return f
    }()

    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return strict.date(from: string) ?? fractional.date(from: string)
    }

    /// « il y a 3 mois ».
    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

extension Comment {
    init(item: CommentItem) {
        id = item.id
        author = item.snippet.authorDisplayName ?? "Anonyme"
        text = (item.snippet.textOriginal ?? item.snippet.textDisplay ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        publishedAt = CommentDates.parse(item.snippet.publishedAt)
    }

    static func chronological(_ a: Comment, _ b: Comment) -> Bool {
        (a.publishedAt ?? .distantPast) < (b.publishedAt ?? .distantPast)
    }
}

extension CommentThread {
    init(item: CommentThreadItem) {
        let inlineReplies = (item.replies?.comments ?? []).map(Comment.init(item:)).sorted(by: Comment.chronological)
        id = item.id
        comment = Comment(item: item.snippet.topLevelComment)
        replies = inlineReplies
        totalReplyCount = item.snippet.totalReplyCount ?? inlineReplies.count
        allRepliesLoaded = inlineReplies.count >= (item.snippet.totalReplyCount ?? inlineReplies.count)
    }
}
