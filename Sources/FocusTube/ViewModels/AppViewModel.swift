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
