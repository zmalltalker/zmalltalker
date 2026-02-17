import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: FileTreeViewModel

    var body: some View {
        List(viewModel.rootItems, children: \.optionalChildren, selection: $viewModel.selectedFileURL) { item in
            SidebarRow(item: item)
                .tag(item.url)
        }
        .listStyle(.sidebar)
        .onChange(of: viewModel.selectedFileURL) { newURL in
            if let url = newURL {
                let fileItem = FileItem(
                    id: UUID(),
                    name: url.lastPathComponent,
                    url: url,
                    isDirectory: false,
                    children: nil
                )
                viewModel.selectFile(fileItem)
            }
        }
        // TODO: iOS - use NavigationStack with NavigationLink instead of List selection
    }
}

struct SidebarRow: View {
    let item: FileItem

    var body: some View {
        Label {
            Text(item.displayName)
                .lineLimit(1)
        } icon: {
            Image(systemName: item.isDirectory ? "folder" : "doc.text")
                .foregroundColor(item.isDirectory ? .accentColor : .secondary)
        }
    }
}

// MARK: - Extension for optional children in List

extension FileItem {
    /// Returns children wrapped as optional for SwiftUI List's children parameter.
    /// Returns nil for files and empty directories to avoid disclosure indicators.
    var optionalChildren: [FileItem]? {
        guard isDirectory, let children = children, !children.isEmpty else { return nil }
        return children
    }
}
