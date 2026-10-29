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
