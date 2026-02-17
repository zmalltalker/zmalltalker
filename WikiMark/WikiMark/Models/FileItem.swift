import Foundation

/// Represents a file or directory in the wiki's file tree.
struct FileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileItem]?

    /// Display name without the .md extension for markdown files.
    var displayName: String {
        if !isDirectory && name.hasSuffix(".md") {
            return String(name.dropLast(3))
        }
        return name
    }

    /// The path relative to the root container, used for generating markdown links.
    func relativePath(to rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return name }
        var relative = String(filePath.dropFirst(rootPath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        // Drop .md extension for wiki-style links
        if relative.hasSuffix(".md") {
            relative = String(relative.dropLast(3))
        }
        return relative
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
