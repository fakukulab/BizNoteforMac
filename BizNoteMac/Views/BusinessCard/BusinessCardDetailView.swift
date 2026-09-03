import SwiftUI
import SwiftData
import AppKit

/// Shown in the detail column when a card is selected in the "명함 관리"
/// smart folder — displays the scanned image alongside an editable form so
/// the extracted fields can be corrected after the fact.
struct BusinessCardDetailView: View {
    @Bindable var card: BusinessCard
    @Environment(\.modelContext) private var context

    private var image: NSImage? {
        AttachmentStorage.loadCardImage(path: card.imagePath)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }

                Form {
                    Section {
                        LabeledContent(String(localized: "card.field.name")) {
                            TextField("", text: $card.name).textFieldStyle(.roundedBorder)
                        }
                        LabeledContent(String(localized: "card.field.company")) {
                            TextField("", text: $card.company).textFieldStyle(.roundedBorder)
                        }
                        LabeledContent(String(localized: "card.field.department")) {
                            TextField("", text: $card.department).textFieldStyle(.roundedBorder)
                        }
                        LabeledContent(String(localized: "card.field.jobTitle")) {
                            TextField("", text: $card.jobTitle).textFieldStyle(.roundedBorder)
                        }
                    }
                    Section {
                        LabeledContent(String(localized: "card.field.email")) {
                            TextField("", text: $card.email).textFieldStyle(.roundedBorder)
                        }
                        LabeledContent(String(localized: "card.field.phone")) {
                            TextField("", text: $card.phone).textFieldStyle(.roundedBorder)
                        }
                        LabeledContent(String(localized: "card.field.officePhone")) {
                            TextField("", text: $card.officePhone).textFieldStyle(.roundedBorder)
                        }
                    }
                    Section {
                        LabeledContent(String(localized: "card.field.website")) {
                            TextField("", text: $card.website).textFieldStyle(.roundedBorder)
                        }
                        LabeledContent(String(localized: "card.field.memo")) {
                            TextEditor(text: $card.memo)
                                .frame(minHeight: 60)
                                .padding(4)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                                .scrollContentBackground(.hidden)
                        }
                    }
                    if let note = card.note {
                        Section {
                            LabeledContent(String(localized: "cardDetail.note", defaultValue: "연결된 노트")) {
                                Text(note.title.isEmpty ? String(localized: "note.untitled") : note.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
            .padding(24)
        }
        .navigationTitle(card.name.isEmpty ? String(localized: "note.untitled") : card.name)
        .onChange(of: card.name) { _, _ in save() }
        .onChange(of: card.company) { _, _ in save() }
        .onChange(of: card.department) { _, _ in save() }
        .onChange(of: card.jobTitle) { _, _ in save() }
        .onChange(of: card.email) { _, _ in save() }
        .onChange(of: card.phone) { _, _ in save() }
        .onChange(of: card.officePhone) { _, _ in save() }
        .onChange(of: card.website) { _, _ in save() }
        .onChange(of: card.memo) { _, _ in save() }
    }

    private func save() {
        try? context.save()
    }
}
