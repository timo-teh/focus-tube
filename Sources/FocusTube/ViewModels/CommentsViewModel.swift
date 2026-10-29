import Foundation
import Combine

/// ViewModel des commentaires d'une vidéo : pagination, réponses, quota.
@MainActor
final class CommentsViewModel: ObservableObject {

    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let videoId: String

    @Published private(set) var threads: [CommentThread] = []
    @Published private(set) var status: Status = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var nextPageToken: String?
    @Published private(set) var expandedThreads: Set<String> = []
    @Published private(set) var threadsLoadingReplies: Set<String> = []

    private let service = CommentsService()
    private var quota: QuotaTracker?
    private var apiKeyProvider: () -> String? = { nil }

    init(videoId: String) {
        self.videoId = videoId
    }

    /// À appeler une fois, avant `loadInitial()`.
    func configure(apiKeyProvider: @escaping () -> String?, quota: QuotaTracker) {
        self.apiKeyProvider = apiKeyProvider
        self.quota = quota
    }

    var canLoadMore: Bool { nextPageToken != nil && !isLoadingMore }

    // MARK: - Chargement

    func loadInitial() async {
        guard status == .idle else { return }
        status = .loading
        do {
            let page = try await fetchPage(token: nil)
            threads = page.threads
            nextPageToken = page.nextPageToken
            status = .loaded
        } catch {
            status = .failed(describe(error))
        }
    }

    func loadMore() async {
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetchPage(token: token)
            let known = Set(threads.map(\.id))
            threads += page.threads.filter { !known.contains($0.id) }
            nextPageToken = page.nextPageToken
        } catch {
            status = .failed(describe(error))
        }
    }

    /// Déplie ou replie les réponses ; charge le reste des réponses si l'API n'en a inclus qu'une partie.
    func toggleReplies(for thread: CommentThread) async {
        if expandedThreads.contains(thread.id) {
            expandedThreads.remove(thread.id)
            return
        }
        expandedThreads.insert(thread.id)

        guard thread.hasUnloadedReplies, !threadsLoadingReplies.contains(thread.id),
              let apiKey = apiKeyProvider() else { return }

        threadsLoadingReplies.insert(thread.id)
        defer { threadsLoadingReplies.remove(thread.id) }

        do {
            let replies = try await service.replies(parentId: thread.id, apiKey: apiKey)
            quota?.record(CommentsConfig.listCost)
            if let index = threads.firstIndex(where: { $0.id == thread.id }) {
                threads[index].replies = replies
                threads[index].allRepliesLoaded = true
            }
        } catch {
            // On garde les réponses déjà incluses par l'API ; pas d'alerte pour un détail.
        }
    }

    // MARK: - Privé

    private func fetchPage(token: String?) async throws -> CommentsService.ThreadsPage {
        guard let apiKey = apiKeyProvider() else { throw CommentsService.CommentsError.invalidAPIKey }
        let page = try await service.threads(videoId: videoId, pageToken: token, apiKey: apiKey)
        quota?.record(CommentsConfig.listCost)
        return page
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
