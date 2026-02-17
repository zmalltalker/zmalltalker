import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: FileTreeViewModel

    @State private var showNewFileDialog = false
    @State private var showNewFolderDialog = false
    @State private var newItemName = ""

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 350)
        } detail: {
            if viewModel.selectedFileURL != nil {
                DocumentView()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a note or create a new one")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Cmd+N to create a new file")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showNewFileDialog = true }) {
                    Label("New File", systemImage: "doc.badge.plus")
                }

                Button(action: { showNewFolderDialog = true }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }

                if viewModel.selectedFileURL != nil {
                    Button(action: { viewModel.isEditing.toggle() }) {
                        Label(
                            viewModel.isEditing ? "View" : "Edit",
                            systemImage: viewModel.isEditing ? "eye" : "pencil"
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showNewFileDialog) {
            NewItemSheet(title: "New File", placeholder: "Note name", isPresented: $showNewFileDialog) { name in
                viewModel.createNewFile(name: name)
            }
        }
        .sheet(isPresented: $showNewFolderDialog) {
            NewItemSheet(title: "New Folder", placeholder: "Folder name", isPresented: $showNewFolderDialog) { name in
                viewModel.createNewFolder(name: name)
            }
        }
        .sheet(isPresented: $viewModel.showCreateFileSheet) {
            CreateMissingFileSheet()
        }
        .sheet(isPresented: $viewModel.showLinkSearch) {
            LinkSearchPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFileRequested)) { _ in
            showNewFileDialog = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFolderRequested)) { _ in
            showNewFolderDialog = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleEditMode)) { _ in
            if viewModel.selectedFileURL != nil {
                viewModel.isEditing.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertLinkRequested)) { _ in
            if viewModel.selectedFileURL != nil && viewModel.isEditing {
                viewModel.showLinkSearch = true
            }
        }
    }
}

// MARK: - New Item Sheet

struct NewItemSheet: View {
    let title: String
    let placeholder: String
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            TextField(placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit {
                    createAndDismiss()
                }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func createAndDismiss() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        isPresented = false
    }
}
