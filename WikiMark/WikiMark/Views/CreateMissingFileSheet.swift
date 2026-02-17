import SwiftUI

/// Sheet displayed when a wiki link target does not exist, offering to create it.
struct CreateMissingFileSheet: View {
    @EnvironmentObject var viewModel: FileTreeViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text("Note Not Found")
                .font(.headline)

            Text("Create '\(viewModel.pendingCreateFileName)'?")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.showCreateFileSheet = false
                    viewModel.pendingCreateFileName = ""
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    let name = viewModel.pendingCreateFileName
                    viewModel.showCreateFileSheet = false
                    viewModel.pendingCreateFileName = ""
                    viewModel.createNewFile(name: name)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
