# WikiMark

A native macOS personal wiki app built with SwiftUI. Your notes are plain Markdown files stored in iCloud Drive — no database, no proprietary format, no lock-in.

## Features

- **Markdown-native** — Every note is a `.md` file in a real folder. Edit them in WikiMark, Vim, or any text editor.
- **iCloud sync** — Files live in your iCloud Drive ubiquity container. They sync automatically across your Macs.
- **Wiki links** — Link between notes with `[Title](other-note)`. Click a link to navigate; if the target doesn't exist, WikiMark offers to create it.
- **Live-preview editing** — The editor renders markdown inline: headings appear large, bold text appears bold, code gets a background, and syntax markers are dimmed. You see the formatting while editing the raw markdown.
- **Formatting shortcuts** — Cmd+B for bold, Cmd+I for italic, Cmd+J for code, Cmd+Shift+H to cycle heading levels, Cmd+Shift+D for strikethrough. Toolbar buttons too.
- **HTML view** — Toggle to a fully rendered HTML view with a custom stylesheet, rendered via WKWebView + cmark.
- **Fast navigation** — Cmd+K opens a quick search panel to insert links to any note in your wiki.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+N | New file |
| Cmd+Shift+N | New folder |
| Cmd+E | Toggle edit / view mode |
| Cmd+K | Insert link to existing note |
| Cmd+B | Bold |
| Cmd+I | Italic |
| Cmd+J | Inline code |
| Cmd+Shift+H | Cycle heading level (H1 → H2 → ... → H6 → plain) |
| Cmd+Shift+D | Strikethrough |

## Architecture

```
WikiMark/
├── Models/
│   └── FileItem.swift              # Recursive file/folder tree node
├── ViewModels/
│   └── FileTreeViewModel.swift     # Scans filesystem, manages selection & autosave
├── Views/
│   ├── ContentView.swift           # NavigationSplitView shell + toolbar
│   ├── SidebarView.swift           # Recursive folder tree (List with children:)
│   ├── DocumentView.swift          # Edit/view toggle + wiki link routing
│   ├── MarkdownEditorView.swift    # Plain TextEditor fallback (unused)
│   ├── RichMarkdownEditor.swift   # Live-preview editor (NSTextView + highlighting)
│   ├── MarkdownViewerView.swift    # WKWebView with CSS injection
│   ├── CreateMissingFileSheet.swift
│   └── LinkSearchPanel.swift       # Cmd+K command palette
├── Utilities/
│   ├── FileCoordinatorHelper.swift # NSFileCoordinator wrapper
│   ├── ICloudContainerHelper.swift # iCloud container discovery + local fallback
│   ├── MarkdownRenderer.swift      # cmark C API bridge
│   └── MarkdownHighlighter.swift  # Regex-based syntax highlighting for editor
└── Resources/
    ├── markdown.css                # Light + dark mode stylesheet
    └── Assets.xcassets/
```

### Key design decisions

- **Filesystem is the source of truth.** No Core Data, no SQLite. `FileTreeViewModel` scans the directory tree and watches for changes via GCD dispatch sources.
- **NSFileCoordinator for all I/O.** Every read, write, and directory creation goes through coordinated access so iCloud sync doesn't cause conflicts.
- **500ms debounced autosave.** Edits are written to disk after a short pause using Combine's `delay` operator.
- **Custom URL scheme for link interception.** The WKWebView loads HTML with a `wikimark://` base URL. Relative links like `href="other-note"` resolve to `wikimark://wiki/other-note`, which the navigation delegate intercepts and routes through the file tree.
- **Live-preview editor.** Built on NSTextView with a custom `MarkdownHighlighter` that uses regex to identify markdown syntax and apply rich attributes. Headings are large, bold text is bold, code has a monospace background, and syntax markers (`**`, `#`, etc.) are dimmed. The raw markdown is always the source of truth — no lossy round-trip conversion.

## Requirements

- macOS 13.0+
- Xcode 15+
- An Apple Developer account (for iCloud entitlements)

## Getting Started

1. Open `WikiMark.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve the [cmark](https://github.com/commonmark/cmark) dependency
3. Set your Development Team in **Signing & Capabilities**
4. Enable the **iCloud** capability with **CloudKit** documents if not already configured
5. Build and run (Cmd+R)

If iCloud is unavailable (e.g., not signed in), WikiMark falls back to `~/Library/Application Support/WikiMark/Documents/`.

## Wiki Links

Link between notes using standard Markdown link syntax with relative paths:

```markdown
See [my other note](other-note) for details.
Check the [project plan](projects/plan) in the projects folder.
```

WikiMark resolves links case-insensitively and automatically appends `.md` when searching. If the target file doesn't exist, you'll be prompted to create it.

## iOS

The codebase is structured for multiplatform support but currently targets macOS only. Search for `// TODO: iOS` comments to find the adaptation points — primarily `UIViewRepresentable` for the WKWebView and `NavigationStack` for the sidebar.

## License

MIT
