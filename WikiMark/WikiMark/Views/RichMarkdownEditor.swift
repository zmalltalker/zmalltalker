import SwiftUI
import AppKit

// MARK: - Custom NSTextView subclass

/// An NSTextView configured for markdown editing with keyboard shortcut handling.
class MarkdownTextView: NSTextView {

    /// Intercepts Cmd+B / Cmd+I before AppKit's rich text system handles them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, let chars = event.characters {
            switch chars {
            case "b":
                NotificationCenter.default.post(name: .formatBold, object: nil)
                return true
            case "i":
                NotificationCenter.default.post(name: .formatItalic, object: nil)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Forces paste to always insert plain text so markdown source stays clean.
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }
}

// MARK: - SwiftUI Wrapper

/// A live-preview markdown editor built on NSTextView.
/// Raw markdown is displayed with inline rich styling — headings appear large,
/// bold text appears bold, code gets a background, and syntax markers are dimmed.
struct RichMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var onTextChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MarkdownTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? MarkdownTextView else {
            // scrollableTextView creates a plain NSTextView; we need our subclass.
            // Rebuild with MarkdownTextView.
            return buildScrollView(context: context)
        }
        configureTextView(textView, context: context)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        context.coordinator.parent = self

        // Only update when the text changed externally (e.g. file navigation)
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            let selection = textView.selectedRange()
            textView.string = text
            context.coordinator.applyHighlighting(to: textView)
            // Clamp selection to valid range after replacing text
            let maxLoc = (textView.string as NSString).length
            let safeLoc = min(selection.location, maxLoc)
            textView.setSelectedRange(NSRange(location: safeLoc, length: 0))
            context.coordinator.isUpdating = false
        }
    }

    /// Builds the scroll view with our custom MarkdownTextView.
    private func buildScrollView(context: Context) -> NSScrollView {
        let textView = MarkdownTextView()
        textView.autoresizingMask = [.width, .height]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 20, height: 16)

        configureTextView(textView, context: context)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        return scrollView
    }

    /// Common configuration shared between makeNSView paths.
    private func configureTextView(_ textView: MarkdownTextView, context: Context) {
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 20, height: 16)
        textView.textContainer?.widthTracksTextView = true

        // Set initial text and highlight
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(to: textView)

        // Listen for formatting commands
        let nc = NotificationCenter.default
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.formatBold),
                       name: .formatBold, object: nil)
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.formatItalic),
                       name: .formatItalic, object: nil)
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.formatCode),
                       name: .formatCode, object: nil)
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.formatHeading),
                       name: .formatHeading, object: nil)
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.formatStrikethrough),
                       name: .formatStrikethrough, object: nil)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichMarkdownEditor
        var isUpdating = false
        weak var textView: MarkdownTextView?
        let highlighter = MarkdownHighlighter()

        init(parent: RichMarkdownEditor) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? MarkdownTextView else { return }

            isUpdating = true
            parent.text = textView.string
            parent.onTextChange()
            applyHighlighting(to: textView)
            isUpdating = false
        }

        /// Applies syntax highlighting without changing the string content.
        func applyHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let sel = textView.selectedRange()
            highlighter.highlight(textStorage)
            // Restore selection (highlight only changed attributes, not text)
            let maxLoc = (textView.string as NSString).length
            if sel.location + sel.length <= maxLoc {
                textView.setSelectedRange(sel)
            }
        }

        // MARK: - Formatting Commands

        @objc func formatBold() {
            toggleInlineMarker("**")
        }

        @objc func formatItalic() {
            toggleInlineMarker("*")
        }

        @objc func formatCode() {
            toggleInlineMarker("`")
        }

        @objc func formatStrikethrough() {
            toggleInlineMarker("~~")
        }

        @objc func formatHeading() {
            guard let textView else { return }
            let nsText = textView.string as NSString
            let sel = textView.selectedRange()

            // Find the line range containing the selection
            let lineRange = nsText.lineRange(for: NSRange(location: sel.location, length: 0))
            let line = nsText.substring(with: lineRange)

            // Count existing # prefix
            var hashCount = 0
            for ch in line {
                if ch == "#" { hashCount += 1 }
                else { break }
            }

            var newLine: String
            if hashCount == 0 {
                // Add h1
                let trimmed = line.trimmingCharacters(in: .newlines)
                newLine = "# \(trimmed)\n"
            } else if hashCount >= 6 {
                // Remove heading (strip all # and the space)
                newLine = String(line.drop(while: { $0 == "#" }).drop(while: { $0 == " " }))
                if !newLine.hasSuffix("\n") && lineRange.location + lineRange.length < nsText.length {
                    newLine += "\n"
                }
            } else {
                // Cycle to next heading level
                let content = String(line.drop(while: { $0 == "#" }).drop(while: { $0 == " " }))
                let hashes = String(repeating: "#", count: hashCount + 1)
                newLine = "\(hashes) \(content)"
                if !newLine.hasSuffix("\n") && lineRange.location + lineRange.length < nsText.length {
                    newLine += "\n"
                }
            }

            textView.insertText(newLine, replacementRange: lineRange)
            parent.text = textView.string
            parent.onTextChange()
            applyHighlighting(to: textView)
        }

        /// Toggles an inline marker (`**`, `*`, `` ` ``, `~~`) around the current selection.
        private func toggleInlineMarker(_ marker: String) {
            guard let textView else { return }
            let nsText = textView.string as NSString
            let sel = textView.selectedRange()
            let markerLen = marker.count

            if sel.length == 0 {
                // No selection: insert paired markers and place cursor between them
                let insertion = "\(marker)\(marker)"
                textView.insertText(insertion, replacementRange: sel)
                textView.setSelectedRange(NSRange(location: sel.location + markerLen, length: 0))
            } else {
                // Check if already wrapped — remove markers
                let beforeStart = sel.location - markerLen
                let afterEnd = sel.location + sel.length

                if beforeStart >= 0 && afterEnd + markerLen <= nsText.length {
                    let before = nsText.substring(with: NSRange(location: beforeStart, length: markerLen))
                    let after = nsText.substring(with: NSRange(location: afterEnd, length: markerLen))

                    if before == marker && after == marker {
                        // Remove existing markers
                        let fullRange = NSRange(location: beforeStart, length: sel.length + markerLen * 2)
                        let content = nsText.substring(with: sel)
                        textView.insertText(content, replacementRange: fullRange)
                        textView.setSelectedRange(NSRange(location: beforeStart, length: sel.length))
                        syncAndHighlight(textView)
                        return
                    }
                }

                // Wrap selection in markers
                let selected = nsText.substring(with: sel)
                let wrapped = "\(marker)\(selected)\(marker)"
                textView.insertText(wrapped, replacementRange: sel)
                textView.setSelectedRange(NSRange(location: sel.location + markerLen, length: sel.length))
            }

            syncAndHighlight(textView)
        }

        private func syncAndHighlight(_ textView: NSTextView) {
            parent.text = textView.string
            parent.onTextChange()
            applyHighlighting(to: textView)
        }
    }
}

// TODO: iOS — create a UIViewRepresentable version using UITextView with NSAttributedString highlighting
