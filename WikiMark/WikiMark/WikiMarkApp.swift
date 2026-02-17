import SwiftUI

@main
struct WikiMarkApp: App {
    @StateObject private var fileTreeViewModel = FileTreeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileTreeViewModel)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    NotificationCenter.default.post(name: .newFileRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Folder") {
                    NotificationCenter.default.post(name: .newFolderRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .textEditing) {
                Button("Toggle Edit/View") {
                    NotificationCenter.default.post(name: .toggleEditMode, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Insert Link") {
                    NotificationCenter.default.post(name: .insertLinkRequested, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newFileRequested = Notification.Name("newFileRequested")
    static let newFolderRequested = Notification.Name("newFolderRequested")
    static let toggleEditMode = Notification.Name("toggleEditMode")
    static let insertLinkRequested = Notification.Name("insertLinkRequested")
}
