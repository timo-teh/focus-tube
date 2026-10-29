import Foundation

/// Page HTML minimale qui héberge le lecteur officiel YouTube (IFrame Player API).
///
/// Le lecteur est une simple « surface d'affichage » (`controls=0`, `disablekb=1`). Toutes les
/// commandes passent par les fonctions `ft…` appelées depuis Swift ; les événements remontent
/// par le message handler `focusTube`. Aucun flux n'est téléchargé ni décodé par l'application.
///
/// Sous-titres : module « captions » de l'API (loadModule / unloadModule / setOption).
/// Langue audio : l'API n'expose pas les pistes audio ; on recharge le lecteur avec le
/// paramètre `hl`, sur lequel YouTube se base pour choisir un doublage lorsqu'il en existe un.
enum PlayerHTML {

    static func page(videoId: String) -> String {
        let safeId = videoId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let captionLanguage = LanguagesConfig.preferredCaptionLanguage
            .map { "'" + $0.filter { $0.isLetter || $0 == "-" } + "'" } ?? "null"

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
            #wrap, #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
          </style>
        </head>
        <body>
          <div id="wrap"><div id="player"></div></div>
          <script>
            var ftPlayer = null;
            var ftTimer = null;
            var ftMaxRate = \(AppConfig.maxPlaybackRate);
            var ftRate = 1;
            var ftCaptions = { wanted: \(LanguagesConfig.captionsOnByDefault), language: \(captionLanguage) };
            var ftAudioLanguage = null;

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

            // ── Sous-titres ─────────────────────────────────────────────────────────
            function ftReadCaptions() {
              if (!ftPlayer || typeof ftPlayer.getOptions !== 'function') { return; }
              var modules = ftPlayer.getOptions() || [];
              if (modules.indexOf('captions') < 0) { return; }
              var list = ftPlayer.getOption('captions', 'tracklist') || [];
              var current = ftPlayer.getOption('captions', 'track') || {};
              ftSend('captions', {
                tracks: list.map(function (t) {
                  return { code: t.languageCode || '', name: t.displayName || t.languageName || t.languageCode || '' };
                }),
                current: current.languageCode || null
              });
            }

            function ftApplyCaptions() {
              if (!ftPlayer || typeof ftPlayer.setOption !== 'function') { return; }
              if (ftCaptions.wanted) {
                if (ftCaptions.language) { ftPlayer.setOption('captions', 'track', { languageCode: ftCaptions.language }); }
              } else {
                ftPlayer.setOption('captions', 'track', {});
              }
            }

            function ftCaptionsOn(code) {
              ftCaptions.wanted = true;
              ftCaptions.language = code || null;
              if (ftPlayer) { ftPlayer.loadModule('captions'); ftApplyCaptions(); ftReadCaptions(); }
            }

            function ftCaptionsOff() {
              ftCaptions.wanted = false;
              if (ftPlayer && typeof ftPlayer.setOption === 'function') {
                ftPlayer.setOption('captions', 'track', {});
                ftPlayer.unloadModule('captions');
              }
            }

            // ── Création (et re-création) du lecteur ────────────────────────────────
            function ftCreatePlayer(startSeconds) {
              var vars = {
                autoplay: 1, controls: 0, disablekb: 1, fs: 0, rel: 0, iv_load_policy: 3,
                modestbranding: 1, playsinline: 1, enablejsapi: 1, origin: window.location.origin
              };
              if (ftAudioLanguage) { vars.hl = ftAudioLanguage; }
              if (ftCaptions.language) { vars.cc_lang_pref = ftCaptions.language; }
              if (ftCaptions.wanted) { vars.cc_load_policy = 1; }
              if (startSeconds > 0) { vars.start = Math.floor(startSeconds); }

              ftPlayer = new YT.Player('player', {
                videoId: '\(safeId)',
                playerVars: vars,
                events: {
                  onReady: function () {
                    ftSend('ready', { duration: ftPlayer.getDuration() || 0 });
                    if (ftRate !== 1) { ftPlayer.setPlaybackRate(ftRate); }
                    // Charge le module pour connaître les pistes ; l'affichage est réglé dans onApiChange.
                    ftPlayer.loadModule('captions');
                    ftSendTime();
                  },
                  onApiChange: function () { ftReadCaptions(); ftApplyCaptions(); },
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

            function onYouTubeIframeAPIReady() { ftCreatePlayer(0); }

            // Langue audio : recharge le lecteur à la même position avec le paramètre hl.
            function ftSetAudioLanguage(code) {
              ftAudioLanguage = code || null;
              var position = (ftPlayer && typeof ftPlayer.getCurrentTime === 'function') ? (ftPlayer.getCurrentTime() || 0) : 0;
              ftStopTimer();
              if (ftPlayer) { try { ftPlayer.destroy(); } catch (e) {} ftPlayer = null; }
              document.getElementById('wrap').innerHTML = '<div id="player"></div>';
              ftSend('stateChange', -1);
              ftCreatePlayer(position);
            }

            // ── Commandes appelées depuis Swift (API officielle du lecteur uniquement) ──
            function ftPlay() { if (ftPlayer) { ftPlayer.playVideo(); } }
            function ftPause() { if (ftPlayer) { ftPlayer.pauseVideo(); } }
            function ftStop() { ftStopTimer(); if (ftPlayer) { ftPlayer.stopVideo(); } }
            function ftSeek(seconds) { if (ftPlayer) { ftPlayer.seekTo(seconds, true); ftSendTime(); } }
            function ftSetRate(rate) { ftRate = Math.min(rate, ftMaxRate); if (ftPlayer) { ftPlayer.setPlaybackRate(ftRate); } }
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
