import SwiftUI

struct AutoHeightTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 34

    var body: some View {
        TextEditor(text: $text)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: minHeight, alignment: .topLeading)
    }
}
