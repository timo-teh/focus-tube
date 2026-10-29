import SwiftUI

/// Écran de lecture : la vidéo (seule chose en couleur), la vitesse, le titre,
/// la chaîne et la description. Aucune suggestion, aucun commentaire.
struct PlayerView: View {
    @EnvironmentObject private var app: AppViewModel
    @StateObject private var viewModel: PlayerViewModel

    init(video: Video) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(video: video))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    player
                    rateSelector
                    metadata
                }
                .padding(28)
            }
        }
    }

    // MARK: - Barre supérieure

    private var toolbar: some View {
        HStack {
            Button {
                app.showSearch()
            } label: {
                Label("Nouvelle recherche", systemImage: "chevron.left")
            }
            .buttonStyle(MonoButtonStyle())
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    // MARK: - Lecteur et surcouches

    private var player: some View {
        ZStack {
            YouTubePlayerWebView(viewModel: viewModel)

            if viewModel.showPauseOverlay {
                pauseOverlay
            }

            if viewModel.state == .ended {
                endedOverlay
            }

            if case .error(let message) = viewModel.state {
                errorOverlay(message)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: 1100)
        .background(Color.black)
        .cornerRadius(6)
        .frame(maxWidth: .infinity)
    }

    /// Pendant la pause, YouTube affiche des suggestions au centre du lecteur.
    /// On les masque en laissant la barre de contrôle (en bas) accessible.
    private var pauseOverlay: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.opacity(0.96)
                VStack(spacing: 12) {
                    Text("En pause")
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                    Button("Reprendre") { viewModel.play() }
                        .buttonStyle(MonoButtonStyle(prominent: true))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.play() }

            Color.clear.frame(height: 56) // zone des contrôles YouTube
        }
    }

    /// Fin de vidéo : écran de fin masqué, aucune lecture automatique.
    private var endedOverlay: some View {
        ZStack {
            Color.black
            VStack(spacing: 16) {
                Text("Vidéo terminée")
                    .font(.title)
                    .foregroundColor(Theme.textPrimary)
                Button("Nouvelle recherche") { app.showSearch() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
            }
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        ZStack {
            Color.black
            VStack(spacing: 16) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: 420)
                Button("Nouvelle recherche") { app.showSearch() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
            }
        }
    }

    // MARK: - Vitesse

    /// Sélecteur monochrome. Les vitesses viennent de `AppConfig.allowedPlaybackRates`.
    private var rateSelector: some View {
        HStack(spacing: 8) {
            Text("Vitesse")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)

            ForEach(AppConfig.allowedPlaybackRates, id: \.self) { rate in
                let selected = abs(viewModel.playbackRate - rate) < 0.001
                Button("\(rate.formatted())×") {
                    viewModel.setPlaybackRate(rate)
                }
                .buttonStyle(MonoButtonStyle(prominent: selected))
                .font(.caption)
            }

            Text("maximum \(AppConfig.maxPlaybackRate.formatted())×")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - Métadonnées

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.video.title)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Text(viewModel.video.channelTitle)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            Divider().overlay(Theme.border)

            Text(viewModel.video.description.isEmpty ? "Aucune description." : viewModel.video.description)
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: 1100, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
