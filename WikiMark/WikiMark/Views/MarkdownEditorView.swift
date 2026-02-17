import SwiftUI

struct MarkdownEditorView: View {
    @Binding var text: String
    var onTextChange: () -> Void

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.visible)
            .padding(8)
            .onChange(of: text) { _ in
                onTextChange()
            }
        // TODO: iOS - adjust padding for smaller screens, consider toolbar accessory view for markdown shortcuts
    }
}
