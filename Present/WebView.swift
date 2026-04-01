import SwiftUI
import WebKit

@MainActor
struct WebView: NSViewRepresentable {
    let url: String
    var pageZoom: Double = 1.0

    private var isImageURL: Bool {
        let imageExtensions: Set<String> = [".png", ".gif", ".jpg", ".jpeg", ".webp", ".svg"]
        let path = url.split(separator: "?").first.map(String.init) ?? url
        return imageExtensions.contains { path.lowercased().hasSuffix($0) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = view
        context.coordinator.startListening()
        loadContent(into: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.webView = view
        loadContent(into: view, coordinator: context.coordinator)
    }

    private func loadContent(into view: WKWebView, coordinator: Coordinator) {
        if isImageURL {
            view.pageZoom = 1.0
            let resolved = resolveURL(url)
            guard coordinator.lastLoadedURL != resolved else { return }
            coordinator.lastLoadedURL = resolved
            let html = """
            <!DOCTYPE html>
            <html><head><meta name="viewport" content="width=device-width">
            <style>*{margin:0;padding:0;overflow:hidden}body{background:#000;display:flex;align-items:center;justify-content:center;width:100vw;height:100vh}img{max-width:100vw;max-height:100vh;object-fit:contain}</style>
            </head><body><img src="\(resolved)"></body></html>
            """
            view.loadHTMLString(html, baseURL: nil)
        } else {
            coordinator.lastLoadedURL = nil
            view.pageZoom = pageZoom
            if let parsed = URL(string: url) ?? URL(string: "https://\(url)"), view.url != parsed {
                view.load(URLRequest(url: parsed))
            }
        }
    }

    private func resolveURL(_ raw: String) -> String {
        guard let parsed = URL(string: raw), parsed.scheme != nil else { return "https://\(raw)" }
        return raw
    }

    @MainActor
    final class Coordinator {
        weak var webView: WKWebView?
        var lastLoadedURL: String?
        private var observer: NSObjectProtocol?

        func startListening() {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: .remoteScroll, object: nil, queue: .main
            ) { [weak self] notification in
                guard let dy = notification.userInfo?["dy"] as? Double,
                      let webView = self?.webView else { return }
                webView.evaluateJavaScript("window.scrollBy(0, \(dy));", completionHandler: nil)
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
