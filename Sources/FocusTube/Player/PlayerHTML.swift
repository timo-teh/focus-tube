import Foundation

/// Page HTML minimale qui charge le lecteur officiel YouTube IFrame Player API.
/// Elle est intégrée au binaire (pas de fichier de ressources à embarquer).
///
/// Conformité : le flux vidéo est lu exclusivement par le lecteur officiel YouTube ;
/// l'application ne télécharge rien et ne contourne aucun mécanisme du lecteur.
enum PlayerHTML {

    /// Nom du canal de messages JavaScript → Swift.
    static let messageHandlerName = "focusTube"

    /// Génère la page pour une vidéo donnée.
    static func render(videoId: String) -> String {
        // Un identifiant YouTube ne contient que [A-Za-z0-9_-] : on neutralise tout le reste.
        let safeId = videoId.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let maxRate = AppConfig.maxPlaybackRate

        return """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            html, body {
                margin: 0; padding: 0;
                width: 100%; height: 100%;
                background: #000; overflow: hidden;
            }
            #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
            var MAX_RATE = \(maxRate);
            var VIDEO_ID = "\(safeId)";
            var player = null;

            // Envoi d'un événement vers Swift.
            function post(event, data) {
                try {
                    window.webkit.messageHandlers.\(messageHandlerName).postMessage({
                        event: event,
                        data: (data === undefined) ? null : data
                    });
                } catch (e) { /* hors WKWebView : ignoré */ }
            }

            // Commandes appelées depuis Swift.
            function ftPlay()        { if (player && player.playVideo)       { player.playVideo(); } }
            function ftPause()       { if (player && player.pauseVideo)      { player.pauseVideo(); } }
            function ftStop()        { if (player && player.stopVideo)       { player.stopVideo(); } }
            function ftSetRate(r)    { if (player && player.setPlaybackRate) { player.setPlaybackRate(Math.min(r, MAX_RATE)); } }

            // Chargement de l'API officielle.
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    videoId: VIDEO_ID,
                    playerVars: {
                        rel: 0,                // suggestions limitées à la chaîne (et masquées par l'app)
                        modestbranding: 1,     // logo YouTube discret
                        iv_load_policy: 3,     // pas d'annotations
                        autoplay: 1,
                        controls: 1,
                        fs: 1,
                        playsinline: 1,
                        enablejsapi: 1,
                        origin: 'https://www.youtube.com'
                    },
                    events: {
                        'onReady': onPlayerReady,
                        'onStateChange': onPlayerStateChange,
                        'onPlaybackRateChange': onPlaybackRateChange,
                        'onError': onPlayerError
                    }
                });
            }

            function onPlayerReady(event) {
                event.target.setPlaybackRate(1);
                post('ready', null);
                event.target.playVideo();
            }

            function onPlayerStateChange(event) {
                post('stateChange', event.data);
            }

            // Règle : vitesse plafonnée à MAX_RATE, corrigée immédiatement côté JS.
            function onPlaybackRateChange(event) {
                var rate = event.data;
                if (rate > MAX_RATE) {
                    player.setPlaybackRate(MAX_RATE);
                    rate = MAX_RATE;
                }
                post('rateChange', rate);
            }

            function onPlayerError(event) {
                post('error', event.data);
            }
        </script>
        </body>
        </html>
        """
    }
}
