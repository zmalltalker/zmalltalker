import AppKit

/// Applies rich visual styling to raw markdown text in an NSTextStorage.
/// Uses regex-based pattern matching to identify syntax elements and style them inline —
/// headings appear large, bold text appears bold, code gets a monospace background,
/// and markdown syntax markers are dimmed.
final class MarkdownHighlighter {

    // MARK: - Theme

    struct Theme {
        let textColor: NSColor
        let headingColor: NSColor
        let markerColor: NSColor
        let codeBackground: NSColor
        let codeTextColor: NSColor
        let linkColor: NSColor
        let blockquoteColor: NSColor

        static let light = Theme(
            textColor: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.18, alpha: 1),
            headingColor: NSColor(srgbRed: 0.11, green: 0.12, blue: 0.14, alpha: 1),
            markerColor: NSColor(srgbRed: 0.55, green: 0.58, blue: 0.62, alpha: 1),
            codeBackground: NSColor(srgbRed: 0.96, green: 0.97, blue: 0.98, alpha: 1),
            codeTextColor: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.18, alpha: 1),
            linkColor: NSColor(srgbRed: 0.04, green: 0.41, blue: 0.85, alpha: 1),
            blockquoteColor: NSColor(srgbRed: 0.34, green: 0.38, blue: 0.42, alpha: 1)
        )

        static let dark = Theme(
            textColor: NSColor(srgbRed: 0.90, green: 0.93, blue: 0.95, alpha: 1),
            headingColor: NSColor(srgbRed: 0.94, green: 0.96, blue: 0.99, alpha: 1),
            markerColor: NSColor(srgbRed: 0.28, green: 0.31, blue: 0.35, alpha: 1),
            codeBackground: NSColor(srgbRed: 0.09, green: 0.11, blue: 0.13, alpha: 1),
            codeTextColor: NSColor(srgbRed: 0.90, green: 0.93, blue: 0.95, alpha: 1),
            linkColor: NSColor(srgbRed: 0.35, green: 0.65, blue: 1.0, alpha: 1),
            blockquoteColor: NSColor(srgbRed: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        )

        static var current: Theme {
            let appearance = NSApp.effectiveAppearance
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }

    // MARK: - Fonts

    private let bodySize: CGFloat = 16
    private let codeFontName = "SF Mono"
    private let codeFallbackFontName = "Menlo"

    private func bodyFont() -> NSFont {
        .systemFont(ofSize: bodySize)
    }

    private func boldFont() -> NSFont {
        .boldSystemFont(ofSize: bodySize)
    }

    private func italicFont() -> NSFont {
        NSFontManager.shared.convert(bodyFont(), toHaveTrait: .italicFontMask)
    }

    private func boldItalicFont() -> NSFont {
        NSFontManager.shared.convert(boldFont(), toHaveTrait: .italicFontMask)
    }

    private func headingFont(level: Int) -> NSFont {
        let sizes: [CGFloat] = [28, 24, 20, 18, 17, 16]
        let size = sizes[min(level - 1, sizes.count - 1)]
        let weights: [NSFont.Weight] = [.heavy, .bold, .semibold, .medium, .medium, .medium]
        let weight = weights[min(level - 1, weights.count - 1)]
        return .systemFont(ofSize: size, weight: weight)
    }

    private func codeFont(size: CGFloat? = nil) -> NSFont {
        let s = size ?? (bodySize - 1)
        return NSFont(name: codeFontName, size: s)
            ?? NSFont(name: codeFallbackFontName, size: s)
            ?? .monospacedSystemFont(ofSize: s, weight: .regular)
    }

    // MARK: - Compiled Patterns

    private static let headingRegex = try! NSRegularExpression(
        pattern: "^(#{1,6})\\s+(.+)$", options: .anchorsMatchLines)

    private static let fencedCodeBlockRegex = try! NSRegularExpression(
        pattern: "(^```[^\\n]*$\\n)([\\s\\S]*?)(^```\\s*$)", options: .anchorsMatchLines)

    private static let indentedCodeBlockRegex = try! NSRegularExpression(
        pattern: "^((?:    |\\t).+\\n?)+", options: .anchorsMatchLines)

    private static let boldRegex = try! NSRegularExpression(
        pattern: "(\\*\\*)(.+?)(\\*\\*)", options: [])

    private static let italicRegex = try! NSRegularExpression(
        pattern: "(?<!\\*)(\\*)(?!\\*| )(.+?)(?<! )(\\*)(?!\\*)", options: [])

    private static let inlineCodeRegex = try! NSRegularExpression(
        pattern: "(?<!`)(`)(?!`)(.+?)(?<!`)(`)(?!`)", options: [])

    private static let linkRegex = try! NSRegularExpression(
        pattern: "(\\[)([^\\]]+)(\\]\\()([^)]+)(\\))", options: [])

    private static let imageRegex = try! NSRegularExpression(
        pattern: "(!\\[)([^\\]]*)(\\]\\()([^)]+)(\\))", options: [])

    private static let blockquoteRegex = try! NSRegularExpression(
        pattern: "^(>+)\\s?(.*)$", options: .anchorsMatchLines)

    private static let unorderedListRegex = try! NSRegularExpression(
        pattern: "^(\\s*[-*+])( )", options: .anchorsMatchLines)

    private static let orderedListRegex = try! NSRegularExpression(
        pattern: "^(\\s*\\d+\\.)( )", options: .anchorsMatchLines)

    private static let horizontalRuleRegex = try! NSRegularExpression(
        pattern: "^([-*_]){3,}\\s*$", options: .anchorsMatchLines)

    private static let strikethroughRegex = try! NSRegularExpression(
        pattern: "(~~)(.+?)(~~)", options: [])

    // MARK: - Public API

    /// Applies full markdown highlighting to the given text storage.
    /// Only modifies attributes — never changes the underlying string.
    func highlight(_ textStorage: NSTextStorage) {
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        let theme = Theme.current

        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineSpacing = 4
        defaultParagraph.paragraphSpacing = 2

        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont(),
            .foregroundColor: theme.textColor,
            .paragraphStyle: defaultParagraph,
        ]

        textStorage.beginEditing()
        textStorage.setAttributes(defaultAttrs, range: fullRange)

        // Track code block ranges to skip inline highlighting inside them
        var codeBlockRanges: [NSRange] = []

        // 1. Fenced code blocks (must come first)
        codeBlockRanges += highlightFencedCodeBlocks(textStorage, text: text, theme: theme)

        // 2. Headings
        highlightHeadings(textStorage, text: text, theme: theme)

        // 3. Blockquotes
        highlightBlockquotes(textStorage, text: text, theme: theme)

        // 4. Horizontal rules
        highlightHorizontalRules(textStorage, text: text, theme: theme)

        // 5. Lists
        highlightLists(textStorage, text: text, theme: theme)

        // 6. Inline elements (skip code blocks)
        highlightBold(textStorage, text: text, theme: theme, skip: codeBlockRanges)
        highlightItalic(textStorage, text: text, theme: theme, skip: codeBlockRanges)
        highlightStrikethrough(textStorage, text: text, theme: theme, skip: codeBlockRanges)
        highlightInlineCode(textStorage, text: text, theme: theme, skip: codeBlockRanges)
        highlightLinks(textStorage, text: text, theme: theme, skip: codeBlockRanges)
        highlightImages(textStorage, text: text, theme: theme, skip: codeBlockRanges)

        textStorage.endEditing()
    }

    // MARK: - Block Elements

    private func highlightFencedCodeBlocks(_ ts: NSTextStorage, text: String, theme: Theme) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        Self.fencedCodeBlockRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            let wholeRange = match.range

            // Style the entire block with code font and background
            ts.addAttributes([
                .font: codeFont(),
                .foregroundColor: theme.codeTextColor,
                .backgroundColor: theme.codeBackground,
            ], range: wholeRange)

            // Dim the ``` delimiters
            if match.numberOfRanges >= 4 {
                let openRange = match.range(at: 1)
                let closeRange = match.range(at: 3)
                if openRange.location != NSNotFound {
                    ts.addAttribute(.foregroundColor, value: theme.markerColor, range: openRange)
                }
                if closeRange.location != NSNotFound {
                    ts.addAttribute(.foregroundColor, value: theme.markerColor, range: closeRange)
                }
            }

            ranges.append(wholeRange)
        }

        return ranges
    }

    private func highlightHeadings(_ ts: NSTextStorage, text: String, theme: Theme) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        Self.headingRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            let hashRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            guard hashRange.location != NSNotFound, contentRange.location != NSNotFound else { return }

            let level = hashRange.length // number of # characters
            let font = headingFont(level: level)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            paragraphStyle.paragraphSpacingBefore = level <= 2 ? 12 : 8

            // Style the heading content
            ts.addAttributes([
                .font: font,
                .foregroundColor: theme.headingColor,
                .paragraphStyle: paragraphStyle,
            ], range: match.range)

            // Dim the # markers
            ts.addAttribute(.foregroundColor, value: theme.markerColor, range: hashRange)
        }
    }

    private func highlightBlockquotes(_ ts: NSTextStorage, text: String, theme: Theme) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        Self.blockquoteRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            let markerRange = match.range(at: 1)

            // Style entire line as blockquote
            ts.addAttribute(.foregroundColor, value: theme.blockquoteColor, range: match.range)
            let italic = NSFontManager.shared.convert(self.bodyFont(), toHaveTrait: .italicFontMask)
            ts.addAttribute(.font, value: italic, range: match.range)

            // Dim the > marker
            if markerRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: markerRange)
            }
        }
    }

    private func highlightHorizontalRules(_ ts: NSTextStorage, text: String, theme: Theme) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        Self.horizontalRuleRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            ts.addAttribute(.foregroundColor, value: theme.markerColor, range: match.range)
        }
    }

    private func highlightLists(_ ts: NSTextStorage, text: String, theme: Theme) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for regex in [Self.unorderedListRegex, Self.orderedListRegex] {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                let markerRange = match.range(at: 1)
                if markerRange.location != NSNotFound {
                    ts.addAttribute(.foregroundColor, value: theme.markerColor, range: markerRange)
                }
            }
        }
    }

    // MARK: - Inline Elements

    private func highlightBold(_ ts: NSTextStorage, text: String, theme: Theme, skip: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        Self.boldRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            guard !self.overlaps(match.range, with: skip) else { return }

            let openRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let closeRange = match.range(at: 3)

            // Bold the content
            if contentRange.location != NSNotFound {
                let currentFont = ts.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? self.bodyFont()
                let bold = NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                ts.addAttribute(.font, value: bold, range: contentRange)
            }
            // Dim markers
            if openRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: openRange)
            }
            if closeRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: closeRange)
            }
        }
    }

    private func highlightItalic(_ ts: NSTextStorage, text: String, theme: Theme, skip: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        Self.italicRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            guard !self.overlaps(match.range, with: skip) else { return }

            let openRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let closeRange = match.range(at: 3)

            if contentRange.location != NSNotFound {
                let currentFont = ts.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? self.bodyFont()
                let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                ts.addAttribute(.font, value: italic, range: contentRange)
            }
            if openRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: openRange)
            }
            if closeRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: closeRange)
            }
        }
    }

    private func highlightStrikethrough(_ ts: NSTextStorage, text: String, theme: Theme, skip: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        Self.strikethroughRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            guard !self.overlaps(match.range, with: skip) else { return }

            let openRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let closeRange = match.range(at: 3)

            if contentRange.location != NSNotFound {
                ts.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            }
            if openRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: openRange)
            }
            if closeRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: closeRange)
            }
        }
    }

    private func highlightInlineCode(_ ts: NSTextStorage, text: String, theme: Theme, skip: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        Self.inlineCodeRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            guard !self.overlaps(match.range, with: skip) else { return }

            let openRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let closeRange = match.range(at: 3)

            // Code font and background for the whole match (including backticks)
            ts.addAttributes([
                .font: self.codeFont(),
                .backgroundColor: theme.codeBackground,
                .foregroundColor: theme.codeTextColor,
            ], range: match.range)

            // Dim the backtick markers
            if openRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: openRange)
            }
            if closeRange.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.markerColor, range: closeRange)
            }
        }
    }

    private func highlightLinks(_ ts: NSTextStorage, text: String, theme: Theme, skip: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        Self.linkRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 6 else { return }
            guard !self.overlaps(match.range, with: skip) else { return }

            let bracketOpen = match.range(at: 1)   // [
            let linkText = match.range(at: 2)       // text
            let parenPart = match.range(at: 3)      // ](
            let urlPart = match.range(at: 4)         // url
            let parenClose = match.range(at: 5)     // )

            // Style the link text
            if linkText.location != NSNotFound {
                ts.addAttributes([
                    .foregroundColor: theme.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ], range: linkText)
            }

            // Dim the structural parts: [ ]( url )
            for r in [bracketOpen, parenPart, urlPart, parenClose] {
                if r.location != NSNotFound {
                    ts.addAttribute(.foregroundColor, value: theme.markerColor, range: r)
                }
            }
        }
    }

    private func highlightImages(_ ts: NSTextStorage, text: String, theme: Theme, skip: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        Self.imageRegex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 6 else { return }
            guard !self.overlaps(match.range, with: skip) else { return }

            let prefix = match.range(at: 1)      // ![
            let altText = match.range(at: 2)     // alt
            let middle = match.range(at: 3)      // ](
            let urlPart = match.range(at: 4)     // url
            let suffix = match.range(at: 5)      // )

            if altText.location != NSNotFound {
                ts.addAttribute(.foregroundColor, value: theme.linkColor, range: altText)
            }
            for r in [prefix, middle, urlPart, suffix] {
                if r.location != NSNotFound {
                    ts.addAttribute(.foregroundColor, value: theme.markerColor, range: r)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns true if `range` overlaps with any range in `ranges`.
    private func overlaps(_ range: NSRange, with ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }
}
