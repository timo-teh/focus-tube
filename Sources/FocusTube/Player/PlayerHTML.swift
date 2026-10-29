import Foundation

/// Page HTML minimale qui héberge le lecteur officiel YouTube (IFrame Player API).
///
/// Le lecteur est configuré en simple « surface d'affichage » : `controls=0` (pas de barre YouTube)
/// et `disablekb=1` (pas de raccourcis YouTube). Toutes les commandes (lecture, pause, position,
/// volume, vitesse) passent par les fonctions `ft…` ci-dessous, appelées depuis Swift, et tous
/// les événements remontent vers Swift par le message handler `focusTube`.
/// Aucun flux n'est téléchargé ni décodé par l'application : c'est l'iframe YouTube qui lit.
enum PlayerHTML {

    static func page(videoId: String) -> String {
        // Un identifiant YouTube ne contient que lettres, chiffres, « - » et « _ ».
        let safeId = videoId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
            #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            var ftPlayer = null;
            var ftTimer = null;
            var ftMaxRate = \(AppConfig.maxPlaybackRate);

            function ftSend(event, data) {
              try {
                window.webkit.messageHandlers.focusTube.postMessage({ event: event, data: (data === undefined ? null : data) });
              } catch (e) {}
            }

            function ftSendTime() {
              if (!ftPlayer || typeof ftPlayer.getCurrentTime !== 'function') { return; }
              ftSend('time', { current: ftPlayer.getCurrentTime() || 0, duration: ftPlayer.getDuration() || 0 });
            }

            function ftStartTimer() { ftStopTimer(); ftTimer = setInterval(ftSendTime, 250); }
            function ftStopTimer() { if (ftTimer) { clearInterval(ftTimer); ftTimer = null; } }

            function onYouTubeIframeAPIReady() {
              ftPlayer = new YT.Player('player', {
                videoId: '\(safeId)',
                playerVars: {
                  autoplay: 1,
                  controls: 0,
                  disablekb: 1,
                  fs: 0,
                  rel: 0,
                  iv_load_policy: 3,
                  modestbranding: 1,
                  playsinline: 1,
                  enablejsapi: 1,
                  origin: window.location.origin
                },
                events: {
                  onReady: function () {
                    ftSend('ready', { duration: ftPlayer.getDuration() || 0 });
                    ftSendTime();
                  },
                  onStateChange: function (e) {
                    ftSend('stateChange', e.data);
                    if (e.data === YT.PlayerState.PLAYING) { ftStartTimer(); } else { ftStopTimer(); ftSendTime(); }
                  },
                  onPlaybackRateChange: function (e) {
                    if (e.data > ftMaxRate) { ftPlayer.setPlaybackRate(ftMaxRate); }
                    ftSend('rateChange', e.data);
                  },
                  onError: function (e) { ftStopTimer(); ftSend('error', e.data); }
                }
              });
            }

            // Commandes appelées depuis Swift (API officielle du lecteur uniquement).
            function ftPlay() { if (ftPlayer) { ftPlayer.playVideo(); } }
            function ftPause() { if (ftPlayer) { ftPlayer.pauseVideo(); } }
            function ftStop() { ftStopTimer(); if (ftPlayer) { ftPlayer.stopVideo(); } }
            function ftSeek(seconds) { if (ftPlayer) { ftPlayer.seekTo(seconds, true); ftSendTime(); } }
            function ftSetRate(rate) { if (ftPlayer) { ftPlayer.setPlaybackRate(Math.min(rate, ftMaxRate)); } }
            function ftSetVolume(volume) { if (ftPlayer) { ftPlayer.setVolume(volume); } }
            function ftMute() { if (ftPlayer) { ftPlayer.mute(); } }
            function ftUnmute() { if (ftPlayer) { ftPlayer.unMute(); } }

            var tag = document.createElement('script');
            tag.src = 'https://www.youtube.com/iframe_api';
            document.head.appendChild(tag);
          </script>
        </body>
        </html>
        """
    }
}
