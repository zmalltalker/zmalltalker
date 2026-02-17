import SwiftUI
import AppKit
import WebKit

/// Renders markdown as HTML using WKWebView with cmark and custom CSS injection.
struct MarkdownViewerView: NSViewRepresentable {
    let markdown: String
    var onNavigate: (String) -> Void

    /// Custom scheme used as base URL so relative wiki links are easy to intercept.
    private static let wikiScheme = "wikimark"
    private static let baseURL = URL(string: "wikimark://wiki/")!

    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigate: onNavigate)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Transparent background so it blends with the window
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        let html = buildHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: Self.baseURL)
    }

    /// Converts markdown to a full HTML document with CSS injected.
    private func buildHTML(from markdown: String) -> String {
        let htmlBody = MarkdownRenderer.render(markdown)
        let css = loadCSS()

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(css)
        </style>
        </head>
        <body>
        <article>
        \(htmlBody)
        </article>
        </body>
        </html>
        """
    }

    /// Loads the markdown.css from the app bundle.
    private func loadCSS() -> String {
        guard let url = Bundle.main.url(forResource: "markdown", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return css
    }

    // MARK: - Coordinator (WKNavigationDelegate)

    class Coordinator: NSObject, WKNavigationDelegate {
        var onNavigate: (String) -> Void

        init(onNavigate: @escaping (String) -> Void) {
            self.onNavigate = onNavigate
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow initial page load (loadHTMLString)
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Handle external links (http/https) by opening in the default browser
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Handle wiki links: relative links resolve against our wikimark:// base URL
            // e.g., href="other-note" becomes wikimark://wiki/other-note
            // e.g., href="folder/note" becomes wikimark://wiki/folder/note
            if url.scheme == MarkdownViewerView.wikiScheme {
                // Extract the path relative to the base, stripping the leading /wiki/ prefix
                var path = url.path
                if path.hasPrefix("/wiki/") {
                    path = String(path.dropFirst(6))
                } else if path.hasPrefix("/") {
                    path = String(path.dropFirst())
                }

                if !path.isEmpty {
                    onNavigate(path)
                }
                decisionHandler(.cancel)
                return
            }

            // Catch-all: cancel unknown navigation
            decisionHandler(.cancel)
        }
    }
}

// TODO: iOS - create a UIViewRepresentable version of this view using WKWebView for iOS
