import SwiftUI
import AppKit

/// Écran de lecture : la vidéo (seule chose en couleur), notre barre de contrôle, le titre,
/// la chaîne, la description et les commentaires. Aucune suggestion, aucun compteur.
///
/// L'iframe YouTube ne reçoit jamais la souris (voir `NonInteractiveWebView`) et, en pause ou
/// à la fin, une surcouche opaque la recouvre : ses suggestions restent invisibles.
struct PlayerView: View {
    @EnvironmentObject private var app: AppViewModel
    @StateObject private var viewModel: PlayerViewModel
    @StateObject private var comments: CommentsViewModel
    @State private var isFullScreen = false

    private let controlBarHeight: CGFloat = 48
    private let maxPlayerWidth: CGFloat = 1100
    private let pagePadding: CGFloat = 28

    init(video: Video) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(video: video))
        _comments = StateObject(wrappedValue: CommentsViewModel(videoId: video.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isFullScreen {
                toolbar
                Divider().overlay(Theme.border)
            }

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        playerBlock(in: geometry.size)

                        if !isFullScreen {
                            metadata
                            CommentsSection(viewModel: comments)
                        }
                    }
                    .padding(isFullScreen ? 0 : pagePadding)
                    .frame(maxWidth: .infinity,
                           minHeight: isFullScreen ? geometry.size.height : 0,
                           alignment: isFullScreen ? .center : .top)
                }
                .scrollDisabled(isFullScreen)
            }
        }
        .background(isFullScreen ? Color.black : Color.clear)
        .background(keyboardShortcuts)
        .onAppear {
            isFullScreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
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
                Label("Nouvelle recherche", systemImage: "chevron.left")
            }
            .buttonStyle(MonoButtonStyle())
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()
        }
        .padding(.horizontal, pagePadding)
        .padding(.vertical, 14)
    }

    // MARK: - Lecteur

    private func playerBlock(in available: CGSize) -> some View {
        let size = playerSize(in: available)
        return VStack(spacing: 0) {
            playerSurface
                .frame(width: size.width, height: size.height)

            PlayerControlBar(viewModel: viewModel, isFullScreen: isFullScreen, toggleFullScreen: toggleFullScreen)
                .frame(width: size.width, height: controlBarHeight)
        }
        .background(Color.black)
        .cornerRadius(isFullScreen ? 0 : 6)
        .frame(maxWidth: .infinity)
    }

    /// Taille 16:9 de la vidéo : limitée en largeur dans la page, ajustée à l'écran en plein écran.
    private func playerSize(in available: CGSize) -> CGSize {
        if isFullScreen {
            let maxHeight = max(available.height - controlBarHeight, 100)
            let width = min(available.width, maxHeight * 16 / 9)
            return CGSize(width: width, height: width * 9 / 16)
        }
        let width = max(min(available.width - pagePadding * 2, maxPlayerWidth), 200)
        return CGSize(width: width, height: width * 9 / 16)
    }

    private var playerSurface: some View {
        ZStack {
            YouTubePlayerWebView(viewModel: viewModel)

            // Couche de capture : un clic sur la vidéo = pause / reprise. La souris n'atteint jamais l'iframe.
            Rectangle()
                .fill(Color.black.opacity(0.001))
                .contentShape(Rectangle())
                .onTapGesture { viewModel.togglePlayPause() }

            if viewModel.state == .loading || viewModel.state == .buffering {
                ProgressView()
                    .controlSize(.small)
                    .allowsHitTesting(false)
            }

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
        .clipped()
    }

    /// Pause : surcouche opaque, les suggestions de YouTube restent derrière, invisibles.
    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.97)
            VStack(spacing: 14) {
                Text(viewModel.video.title)
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 520)
                Button("Reprendre") { viewModel.play() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
                Text("Espace : lecture / pause   ·   ← → : ±10 s   ·   F : plein écran")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.play() }
    }

    /// Fin de vidéo : écran de fin masqué, aucune lecture automatique.
    private var endedOverlay: some View {
        ZStack {
            Color.black
            VStack(spacing: 16) {
                Text("Vidéo terminée")
                    .font(.title)
                    .foregroundColor(Theme.textPrimary)
                HStack(spacing: 12) {
                    Button("Revoir") { viewModel.replay() }
                        .buttonStyle(MonoButtonStyle())
                    Button("Nouvelle recherche") { leavePlayer() }
                        .buttonStyle(MonoButtonStyle(prominent: true))
                }
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
                Button("Nouvelle recherche") { leavePlayer() }
                    .buttonStyle(MonoButtonStyle(prominent: true))
            }
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
        .frame(maxWidth: maxPlayerWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Raccourcis clavier (boutons invisibles)

    private var keyboardShortcuts: some View {
        Group {
            Button("") { viewModel.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { viewModel.seek(by: -10) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { viewModel.seek(by: 10) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("") { toggleFullScreen() }
                .keyboardShortcut("f", modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func toggleFullScreen() {
        (NSApp.keyWindow ?? NSApp.windows.first)?.toggleFullScreen(nil)
    }

    private func leavePlayer() {
        if isFullScreen {
            toggleFullScreen()
        }
        app.showSearch()
    }
}
