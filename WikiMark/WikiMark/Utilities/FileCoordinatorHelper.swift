import Foundation

/// Provides coordinated file read/write operations using NSFileCoordinator.
enum FileCoordinatorHelper {

    /// Reads the contents of a file using NSFileCoordinator.
    static func readFile(at url: URL) throws -> String {
        var coordinatorError: NSError?
        var readError: Error?
        var content: String = ""

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordURL in
            do {
                content = try String(contentsOf: coordURL, encoding: .utf8)
            } catch {
                readError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = readError {
            throw error
        }
        return content
    }

    /// Writes string content to a file using NSFileCoordinator.
    static func writeFile(at url: URL, content: String) throws {
        var coordinatorError: NSError?
        var writeError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordURL in
            do {
                try content.write(to: coordURL, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = writeError {
            throw error
        }
    }

    /// Creates a directory using NSFileCoordinator.
    static func createDirectory(at url: URL) throws {
        var coordinatorError: NSError?
        var createError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordURL in
            do {
                try FileManager.default.createDirectory(at: coordURL, withIntermediateDirectories: true)
            } catch {
                createError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = createError {
            throw error
        }
    }

    /// Creates a file with initial content using NSFileCoordinator.
    static func createFile(at url: URL, content: String = "") throws {
        // Ensure the parent directory exists
        let parent = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try createDirectory(at: parent)
        }
        try writeFile(at: url, content: content)
    }
}
