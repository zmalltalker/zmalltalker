import SwiftUI

/// A command-palette-style search panel for inserting wiki links (Cmd+K).
struct LinkSearchPanel: View {
    @EnvironmentObject var viewModel: FileTreeViewModel
    @State private var searchText = ""

    private var filteredFiles: [FileItem] {
        let files = viewModel.allMarkdownFiles
        if searchText.isEmpty {
            return files
        }
        return files.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(12)

            Divider()

            // Results list
            if filteredFiles.isEmpty {
                VStack(spacing: 8) {
                    Text("No matching notes")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredFiles) { file in
                            LinkSearchRow(file: file)
                                .onTapGesture {
                                    insertLink(to: file)
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 400)
        .background(.regularMaterial)
    }

    /// Inserts a relative markdown link at the current cursor position.
    private func insertLink(to file: FileItem) {
        let relativePath = file.relativePath(to: viewModel.rootURL)
        let link = "[\(file.displayName)](\(relativePath))"

        // Append the link to the document content
        // In a full implementation, this would insert at the cursor position.
        // For now, append at the end of the content.
        viewModel.documentContent += link
        viewModel.scheduleAutosave()
        viewModel.showLinkSearch = false
    }
}

struct LinkSearchRow: View {
    let file: FileItem

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.body)
                Text(file.url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color.clear)
    }
}
