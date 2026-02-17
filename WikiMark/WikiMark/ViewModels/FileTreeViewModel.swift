import Foundation
import Combine

/// Manages the file tree by scanning the iCloud container directory and watching for changes.
class FileTreeViewModel: ObservableObject {

    @Published var rootItems: [FileItem] = []
    @Published var selectedFileURL: URL?
    @Published var documentContent: String = ""
    @Published var isEditing: Bool = false
    @Published var showCreateFileSheet: Bool = false
    @Published var pendingCreateFileName: String = ""
    @Published var showLinkSearch: Bool = false

    /// Root URL of the document storage container.
    let rootURL: URL

    private var autosaveTimer: AnyCancellable?
    private var directoryWatcher: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    /// All markdown files flattened from the tree, for search purposes.
    var allMarkdownFiles: [FileItem] {
        flattenFiles(rootItems).filter { !$0.isDirectory && $0.name.hasSuffix(".md") }
    }

    init() {
        self.rootURL = ICloudContainerHelper.rootURL()
        ICloudContainerHelper.createWelcomeNoteIfNeeded(at: rootURL)
        refreshTree()
        startWatching()
    }

    deinit {
        stopWatching()
    }

    // MARK: - Tree Building

    /// Scans the root directory and rebuilds the file tree.
    func refreshTree() {
        rootItems = buildTree(at: rootURL)
    }

    /// Recursively builds a FileItem tree from the filesystem.
    private func buildTree(at url: URL) -> [FileItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [FileItem] = []
        for itemURL in contents.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }) {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues?.isDirectory ?? false

            if isDir {
                let children = buildTree(at: itemURL)
                items.append(FileItem(
                    id: UUID(),
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    isDirectory: true,
                    children: children
                ))
            } else if itemURL.pathExtension == "md" {
                items.append(FileItem(
                    id: UUID(),
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    isDirectory: false,
                    children: nil
                ))
            }
        }
        return items
    }

    /// Flattens the file tree into a single array.
    private func flattenFiles(_ items: [FileItem]) -> [FileItem] {
        var result: [FileItem] = []
        for item in items {
            result.append(item)
            if let children = item.children {
                result.append(contentsOf: flattenFiles(children))
            }
        }
        return result
    }

    // MARK: - File Selection & Reading

    /// Selects a file and loads its content.
    func selectFile(_ item: FileItem) {
        guard !item.isDirectory else { return }
        selectedFileURL = item.url
        loadSelectedFile()
    }

    /// Loads the currently selected file's content.
    func loadSelectedFile() {
        guard let url = selectedFileURL else { return }
        do {
            documentContent = try FileCoordinatorHelper.readFile(at: url)
        } catch {
            documentContent = "Error reading file: \(error.localizedDescription)"
        }
    }

    // MARK: - Autosave

    /// Schedules an autosave after 500ms debounce.
    func scheduleAutosave() {
        autosaveTimer?.cancel()
        autosaveTimer = Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveCurrentFile()
            }
    }

    /// Writes the current document content to disk.
    func saveCurrentFile() {
        guard let url = selectedFileURL else { return }
        try? FileCoordinatorHelper.writeFile(at: url, content: documentContent)
    }

    // MARK: - File/Folder Creation

    /// Creates a new markdown file in the given directory (or root if nil).
    func createNewFile(name: String, in directoryURL: URL? = nil) {
        let parentURL = directoryURL ?? rootURL
        var fileName = name
        if !fileName.hasSuffix(".md") {
            fileName += ".md"
        }
        let fileURL = parentURL.appendingPathComponent(fileName)

        do {
            try FileCoordinatorHelper.createFile(at: fileURL, content: "# \(name.replacingOccurrences(of: ".md", with: ""))\n\n")
            refreshTree()
            selectFile(FileItem(id: UUID(), name: fileName, url: fileURL, isDirectory: false, children: nil))
            isEditing = true
        } catch {
            print("Error creating file: \(error)")
        }
    }

    /// Creates a new folder in the given directory (or root if nil).
    func createNewFolder(name: String, in directoryURL: URL? = nil) {
        let parentURL = directoryURL ?? rootURL
        let folderURL = parentURL.appendingPathComponent(name)

        do {
            try FileCoordinatorHelper.createDirectory(at: folderURL)
            refreshTree()
        } catch {
            print("Error creating folder: \(error)")
        }
    }

    // MARK: - Wiki Link Resolution

    /// Resolves a relative wiki link path to a FileItem.
    /// Searches case-insensitively, with and without .md extension.
    func resolveWikiLink(_ path: String) -> FileItem? {
        let candidates = [path, path + ".md"]
        let allFiles = allMarkdownFiles

        for candidate in candidates {
            // Try exact path relative to root
            let candidateURL = rootURL.appendingPathComponent(candidate)
            if let found = allFiles.first(where: {
                $0.url.standardizedFileURL.path.lowercased() == candidateURL.standardizedFileURL.path.lowercased()
            }) {
                return found
            }

            // Try just by filename match
            let fileName = (candidate as NSString).lastPathComponent
            if let found = allFiles.first(where: {
                $0.name.lowercased() == fileName.lowercased()
            }) {
                return found
            }
        }
        return nil
    }

    /// Returns the parent directory URL for the currently selected file.
    func currentDirectoryURL() -> URL {
        if let selectedURL = selectedFileURL {
            return selectedURL.deletingLastPathComponent()
        }
        return rootURL
    }

    // MARK: - Directory Watching

    /// Starts watching the root directory for changes using GCD dispatch source.
    private func startWatching() {
        fileDescriptor = open(rootURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        directoryWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )

        directoryWatcher?.setEventHandler { [weak self] in
            self?.refreshTree()
        }

        directoryWatcher?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        directoryWatcher?.resume()
    }

    /// Stops watching the directory.
    private func stopWatching() {
        directoryWatcher?.cancel()
        directoryWatcher = nil
    }
}
