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
