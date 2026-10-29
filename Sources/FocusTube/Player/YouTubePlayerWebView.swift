import SwiftUI
import AppKit
import WebKit

/// WKWebView qui ignore totalement la souris : aucun clic ni survol n'atteint l'iframe YouTube.
/// Les bandeaux « Plus de vidéos », « Regarder sur YouTube », « Copier le lien » ne peuvent donc
/// ni apparaître au survol ni être cliqués. Tout le pilotage passe par `PlayerControlBar`.
final class NonInteractiveWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var acceptsFirstResponder: Bool { false }
}

/// Pont SwiftUI ↔ WKWebView pour le lecteur officiel YouTube.
struct YouTubePlayerWebView: NSViewRepresentable {
    @ObservedObject var viewModel: PlayerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "focusTube")
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = NonInteractiveWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.underPageBackgroundColor = .black
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false

        viewModel.jsExecutor = { [weak webView] script in
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }

        // La base « https://com.focustube.app » identifie l'application auprès de YouTube (Referer).
        webView.loadHTMLString(PlayerHTML.page(videoId: viewModel.video.id), baseURL: PlayerOrigin.url)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.evaluateJavaScript("ftStop();", completionHandler: nil)
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "focusTube")
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        private let viewModel: PlayerViewModel
        private var didAllowMainDocument = false

        init(viewModel: PlayerViewModel) {
            self.viewModel = viewModel
        }

        /// Événements envoyés par la page (`ftSend`).
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "focusTube", let body = message.body as? [String: Any] else { return }
            let viewModel = self.viewModel
            Task { @MainActor in viewModel.handle(message: body) }
        }

        /// Seul le document principal (notre page) peut être chargé dans le cadre principal.
        /// Les cadres enfants (l'iframe YouTube) restent libres ; toute autre navigation est bloquée.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            guard isMainFrame else {
                decisionHandler(.allow)
                return
            }
            if didAllowMainDocument {
                decisionHandler(.cancel)
            } else {
                didAllowMainDocument = true
                decisionHandler(.allow)
            }
        }

        /// Aucune fenêtre surgissante.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }
    }
}
