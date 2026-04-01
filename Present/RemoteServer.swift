import Foundation
import Network

extension Notification.Name {
    static let remotePlay = Self("remotePlay")
    static let remoteStop = Self("remoteStop")
    static let remoteScroll = Self("remoteScroll")
}

@MainActor
final class RemoteServer {
    private var listener: NWListener?
    private var state: PresentationState?

    func start(state: PresentationState) {
        self.state = state
        do {
            listener = try .init(using: .tcp, on: 9123)
        } catch {
            print("RemoteServer: failed to create listener: \(error)")
            return
        }
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.handle(connection) }
        }
        listener?.stateUpdateHandler = { print("RemoteServer: \($0)") }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }
            let request = String(data: data, encoding: .utf8) ?? ""
            let response = MainActor.assumeIsolated { self.route(request) }
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func route(_ raw: String) -> String {
        let firstLine = raw.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let path = parts.count >= 2 ? String(parts[1]) : "/"

        switch path {
        case "/next":
            state?.goToNext()
        case "/prev":
            state?.goToPrevious()
        case "/play":
            NotificationCenter.default.post(name: .remotePlay, object: nil)
        case "/stop":
            NotificationCenter.default.post(name: .remoteStop, object: nil)
        case "/zoomin":
            state?.zoomIn()
        case "/zoomout":
            state?.zoomOut()
        case _ where path.hasPrefix("/scroll"):
            if let dy = URLComponents(string: path)?.queryItems?.first(where: { $0.name == "dy" })?.value,
               let delta = Double(dy) {
                NotificationCenter.default.post(name: .remoteScroll, object: nil, userInfo: ["dy": delta])
            }
        case "/status":
            return statusResponse()
        default:
            return htmlResponse()
        }
        return jsonResponse("ok")
    }

    private func jsonResponse(_ status: String) -> String {
        let body = #"{"status":"\#(status)"}"#
        return httpResponse(body: body, contentType: "application/json")
    }

    private func statusResponse() -> String {
        let body = #"{"slide":\#(state?.currentIndex ?? 0 + 1),"total":\#(state?.slides.count ?? 0),"presenting":\#(state?.isPresenting ?? false),"url":"\#((state?.currentSlide?.url ?? "").replacingOccurrences(of: "\"", with: "\\\""))"}"#
        return httpResponse(body: body, contentType: "application/json")
    }

    private func htmlResponse() -> String {
        httpResponse(body: Self.htmlPage, contentType: "text/html; charset=utf-8")
    }

    private func httpResponse(body: String, contentType: String) -> String {
        "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    }

    static let htmlPage = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <title>Present Remote</title>
    <style>
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body {
        font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
        background: #1a1a2e; color: #eee;
        display: flex; flex-direction: column; align-items: center;
        height: 100dvh; padding: 20px; gap: 16px;
        -webkit-user-select: none; user-select: none;
      }
      #status { font-size: 1.6rem; font-weight: 600; text-align: center; min-height: 2em; }
      #url { font-size: 0.85rem; opacity: 0.4; word-break: break-all; text-align: center; max-width: 90vw; }
      .nav-row { display: flex; gap: 16px; width: 100%; max-width: 400px; }
      button {
        flex: 1; padding: 24px 10px; font-size: 1.5rem; font-weight: 600;
        border: none; border-radius: 14px; cursor: pointer;
        transition: transform 0.1s, opacity 0.1s;
        min-height: 80px;
      }
      button:active { transform: scale(0.95); opacity: 0.8; }
      .btn-prev { background: #16213e; color: #e94560; }
      .btn-next { background: #16213e; color: #53d8fb; }
      .btn-play { background: #0f3460; color: #53d8fb; }
      .btn-stop { background: #e94560; color: #fff; }
      .play-row { display: flex; gap: 16px; width: 100%; max-width: 400px; flex: 1; min-height: 0; }
      .play-row button { flex: 1; min-height: 0; height: auto; }
      .scroll-strip {
        width: 50px; flex-shrink: 0; background: #16213e; border-radius: 14px;
        display: flex; align-items: center; justify-content: center;
        color: #555; font-size: 1.2rem; touch-action: none; cursor: grab;
      }
      .scroll-strip:active { cursor: grabbing; background: #1a2740; }
      .zoom-row { display: flex; gap: 16px; width: 100%; max-width: 400px; }
      .btn-zoom { background: #16213e; color: #aaa; font-size: 1.3rem; min-height: 60px; }
      html { touch-action: manipulation; }
    </style>
    </head>
    <body>
      <div id="status">Connecting...</div>
      <div class="nav-row">
        <button class="btn-prev" onclick="send('/prev')">&lsaquo; Prev</button>
        <button class="btn-next" onclick="send('/next')">Next &rsaquo;</button>
      </div>
      <div class="play-row">
        <button id="playBtn" class="btn-play" onclick="togglePlay()">&#9654; Start</button>
        <div class="scroll-strip" id="scrollStrip">&#8597;</div>
      </div>
      <div class="zoom-row">
        <button class="btn-zoom" onclick="send('/zoomout')">A-</button>
        <button class="btn-zoom" onclick="send('/zoomin')">A+</button>
      </div>
      <div id="url"></div>
      <script>
        let presenting = false;
        function send(path) {
          fetch(path).catch(() => {});
        }
        function togglePlay() {
          send(presenting ? '/stop' : '/play');
        }
        function poll() {
          fetch('/status').then(r => r.json()).then(d => {
            document.getElementById('status').textContent =
              'Slide ' + d.slide + ' / ' + d.total;
            document.getElementById('url').textContent = d.url || '';
            presenting = d.presenting;
            const btn = document.getElementById('playBtn');
            if (presenting) {
              btn.textContent = '\\u25A0 Stop';
              btn.className = 'btn-stop';
            } else {
              btn.textContent = '\\u25B6 Start';
              btn.className = 'btn-play';
            }
          }).catch(() => {
            document.getElementById('status').textContent = 'Disconnected';
          });
        }
        setInterval(poll, 1000);
        poll();

        const strip = document.getElementById('scrollStrip');
        let lastY = null;
        let pendingDy = 0;
        let sendTimer = null;
        function flushScroll() {
          if (pendingDy !== 0) {
            fetch('/scroll?dy=' + Math.round(pendingDy)).catch(() => {});
            pendingDy = 0;
          }
          sendTimer = null;
        }
        strip.addEventListener('touchstart', e => {
          e.preventDefault();
          lastY = e.touches[0].clientY;
          pendingDy = 0;
        }, {passive: false});
        strip.addEventListener('touchmove', e => {
          e.preventDefault();
          const y = e.touches[0].clientY;
          if (lastY !== null) {
            pendingDy += (y - lastY) * 2;
            lastY = y;
            if (!sendTimer) {
              sendTimer = setTimeout(flushScroll, 50);
            }
          }
        }, {passive: false});
        strip.addEventListener('touchend', () => {
          lastY = null;
          flushScroll();
          if (sendTimer) { clearTimeout(sendTimer); sendTimer = null; }
        });
      </script>
    </body>
    </html>
    """
}
