import SwiftUI

/// A small toolbar-style menu button that lists the business cards already
/// scanned on the current note, so their fields can be loaded into a
/// participant/contact row instead of retyping them. Renders as a plain
/// icon by default, or as a titled "명함불러오기" text button when
/// `showsLabel` is true.
struct CardLinkButton: View {
    let cards: [BusinessCard]
    var onSelect: (BusinessCard) -> Void
    var showsLabel: Bool = false

    var body: some View {
        Menu {
            if cards.isEmpty {
                Text(String(localized: "cardLink.empty", defaultValue: "스캔된 명함이 없습니다"))
            } else {
                ForEach(cards, id: \.id) { card in
                    Button {
                        onSelect(card)
                    } label: {
                        Text(cardLabel(card))
                    }
                }
            }
        } label: {
            if showsLabel {
                Text(String(localized: "cardLink.label", defaultValue: "명함불러오기"))
            } else {
                Image(systemName: "person.text.rectangle")
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(String(localized: "cardLink.help", defaultValue: "스캔한 명함에서 불러오기"))
    }

    private func cardLabel(_ card: BusinessCard) -> String {
        let name = card.name.isEmpty ? String(localized: "note.untitled") : card.name
        return card.company.isEmpty ? name : "\(name) (\(card.company))"
    }
}
