import Foundation
import cmark

/// Renders markdown to HTML using the cmark C library.
/// cmark is linked via Swift Package Manager.
enum MarkdownRenderer {

    /// Converts a markdown string to an HTML string using cmark.
    static func render(_ markdown: String) -> String {
        guard let cString = markdown.cString(using: .utf8) else {
            return "<p>Error: Could not encode markdown</p>"
        }

        // cmark_markdown_to_html expects the byte length excluding the null terminator
        let len = cString.count - 1
        guard let htmlPtr = cmark_markdown_to_html(cString, len, 0) else {
            return "<p>Error: Could not render markdown</p>"
        }

        let html = String(cString: htmlPtr)
        free(htmlPtr)
        return html
    }
}
