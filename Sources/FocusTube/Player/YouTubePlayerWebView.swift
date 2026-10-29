import SwiftUI
import WebKit

/// Encapsule une WKWebView contenant le lecteur YouTube IFrame.
///
/// Garde-fous :
/// - toute navigation du cadre principal hors de la page initiale est annulée ;
/// - toute ouverture de nouvelle fenêtre (clic sur le logo ou le titre YouTube) est bloquée ;
/// - les événements du lecteur remontent vers `PlayerViewModel`.
struct YouTubePlayerWebView: NSViewRepresentable {

    @ObservedObject var viewModel: PlayerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.userContentController.add(context.coordinator, name: PlayerHTML.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.underPageBackgroundColor = .black

        // Canal Swift → JavaScript.
        viewModel.jsExecutor = { [weak webView] script in
            webView?.evaluateJavaScript(script) { _, _ in }
        }

        // Le baseURL youtube.com est requis par l'IFrame API pour accepter l'intégration.
        let html = PlayerHTML.render(videoId: viewModel.video.id)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Rien à mettre à jour : une vue = une vidéo (voir `.id(video.id)` dans RootView).
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.evaluateJavaScript("ftStop();") { _, _ in }
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: PlayerHTML.messageHandlerName)
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
        nsView.loadHTMLString("", baseURL: nil)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

        private let viewModel: PlayerViewModel
        private var initialLoadAllowed = true

        init(viewModel: PlayerViewModel) {
            self.viewModel = viewModel
        }

        // JavaScript → Swift
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == PlayerHTML.messageHandlerName,
                  let body = message.body as? [String: Any] else { return }
            Task { @MainActor in
                viewModel.handle(message: body)
            }
        }

        // Navigation : n'autoriser que le chargement initial dans le cadre principal.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            // Pas de cadre cible = demande d'ouverture dans une nouvelle fenêtre : refusée.
            guard let targetFrame = navigationAction.targetFrame else {
                decisionHandler(.cancel)
                return
            }

            // Sous-cadres (l'iframe du lecteur lui-même) : autorisés.
            guard targetFrame.isMainFrame else {
                decisionHandler(.allow)
                return
            }

            // Cadre principal : seul le premier chargement (notre HTML) passe.
            if initialLoadAllowed {
                initialLoadAllowed = false
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        // Bloque les fenêtres surgissantes (target="_blank" vers youtube.com).
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }
    }
}
