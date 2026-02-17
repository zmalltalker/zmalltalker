import Foundation

/// Manages the iCloud ubiquity container for document storage.
/// Falls back to a local directory when iCloud is unavailable.
enum ICloudContainerHelper {

    /// The iCloud container identifier.
    /// Update this to match your app's iCloud container ID in the entitlements.
    static let containerIdentifier: String? = nil // Uses default container

    /// Returns the root URL for document storage.
    /// Prefers the iCloud ubiquity container; falls back to a local Application Support directory.
    static func rootURL() -> URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            let documentsURL = iCloudURL.appendingPathComponent("Documents")
            if !FileManager.default.fileExists(atPath: documentsURL.path) {
                try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            }
            return documentsURL
        }

        // Fallback: local storage in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localURL = appSupport.appendingPathComponent("WikiMark/Documents")
        if !FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
        }
        return localURL
    }

    /// Creates a welcome note if the container is empty.
    static func createWelcomeNoteIfNeeded(at rootURL: URL) {
        let welcomeURL = rootURL.appendingPathComponent("Welcome.md")
        guard !FileManager.default.fileExists(atPath: welcomeURL.path) else { return }

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: rootURL.path)) ?? []
        guard contents.isEmpty else { return }

        let welcomeContent = """
        # Welcome to WikiMark

        WikiMark is your personal wiki powered by Markdown files.

        ## Getting Started

        - Create new files with **Cmd+N**
        - Create new folders with **Cmd+Shift+N**
        - Toggle between edit and view mode with **Cmd+E**
        - Insert links to other notes with **Cmd+K**

        ## Wiki Links

        You can link to other notes using relative markdown links:

        - `[My Note](my-note)` links to `my-note.md`
        - `[Sub Note](folder/note)` links to `folder/note.md`

        If the linked note doesn't exist, WikiMark will offer to create it for you.

        ## Storage

        All your notes are stored as `.md` files in iCloud Drive, organized in real folders.
        """

        try? FileCoordinatorHelper.createFile(at: welcomeURL, content: welcomeContent)
    }
}
