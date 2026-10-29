import SwiftUI

/// Écran de lecture.
///
/// Le lecteur YouTube reste visible pendant la pause : aucune capture
/// d'écran ni surcouche ne vient masquer l'image ou les commandes.
/// Les messages de fin et d'erreur sont affichés sous le lecteur.
struct PlayerView: View {
    @EnvironmentObject private var app: AppViewModel
    @StateObject private var viewModel: PlayerViewModel
    @StateObject private var comments: CommentsViewModel

    init(video: Video) {
        _viewModel = StateObject(
            wrappedValue: PlayerViewModel(video: video)
        )
        _comments = StateObject(
            wrappedValue: CommentsViewModel(videoId: video.id)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar

            Divider()
                .overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    player

                    playbackStatus

                    rateSelector

                    metadata

                    CommentsSection(viewModel: comments)
                }
                .padding(28)
            }
        }
        .task {
            comments.configure(apiKeyProvider: { [weak app] in app?.apiKey }, quota: app.quota)
            await comments.loadInitial()
        }
    }

    // MARK: - Barre supérieure

    private var toolbar: some View {
        HStack {
            Button {
                app.showSearch()
            } label: {
                Label(
                    "Nouvelle recherche",
                    systemImage: "chevron.left"
                )
            }
            .buttonStyle(MonoButtonStyle())
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    // MARK: - Lecteur

    private var player: some View {
        YouTubePlayerWebView(viewModel: viewModel)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: 1100)
            .background(Color.black)
            .frame(maxWidth: .infinity)
    }

    /// Les messages sont placés en dehors du lecteur, jamais devant lui.
    @ViewBuilder
    private var playbackStatus: some View {
        switch viewModel.state {
        case .ended:
            HStack {
                Text("Vidéo terminée")
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Button("Nouvelle recherche") {
                    app.showSearch()
                }
                .buttonStyle(MonoButtonStyle())
            }
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)

        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Impossible de lire la vidéo")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Text(message)
                    .foregroundColor(Theme.textSecondary)
                    .textSelection(.enabled)

                Button("Nouvelle recherche") {
                    app.showSearch()
                }
                .buttonStyle(MonoButtonStyle())
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            EmptyView()
        }
    }

    // MARK: - Vitesse

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
        .frame(maxWidth: 1100, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
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

            Divider()
                .overlay(Theme.border)

            Text(
                viewModel.video.description.isEmpty
                    ? "Aucune description."
                    : viewModel.video.description
            )
            .font(.body)
            .foregroundColor(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
        }
        .frame(maxWidth: 1100, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
