import SwiftUI

struct DocumentView: View {
    @EnvironmentObject var viewModel: FileTreeViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isEditing {
                RichMarkdownEditor(
                    text: $viewModel.documentContent,
                    onTextChange: {
                        viewModel.scheduleAutosave()
                    }
                )
            } else {
                MarkdownViewerView(
                    markdown: viewModel.documentContent,
                    onNavigate: { path in
                        handleWikiLink(path)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // TODO: iOS - add swipe gesture to toggle between edit/view
    }

    /// Handles a wiki link navigation request.
    private func handleWikiLink(_ path: String) {
        if let item = viewModel.resolveWikiLink(path) {
            viewModel.selectFile(item)
            viewModel.isEditing = false
        } else {
            // File not found — prompt to create it
            var fileName = path
            if !fileName.hasSuffix(".md") {
                fileName += ".md"
            }
            viewModel.pendingCreateFileName = fileName
            viewModel.showCreateFileSheet = true
        }
    }
}
