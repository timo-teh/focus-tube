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
