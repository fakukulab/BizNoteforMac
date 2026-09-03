import SwiftData
import SwiftUI

struct ExhibitionAddWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var venue = ""
    @State private var introduction = ""
    @State private var exhibitItems = ""
    @State private var organizer = ""
    @State private var supervisor = ""
    @State private var contact = ""
    @State private var homepage = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "exhibitions.add", defaultValue: "행사 추가"))
                .font(.title2.weight(.semibold))

            Form {
                Section {
                    LabeledContent(String(localized: "exhibitions.name", defaultValue: "행사명")) {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent(String(localized: "exhibitions.schedule", defaultValue: "일정")) {
                        HStack {
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                            Text("-")
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent(String(localized: "exhibitions.venue", defaultValue: "장소")) {
                        TextField("", text: $venue)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section {
                    LabeledContent(String(localized: "exhibitions.introduction", defaultValue: "행사소개")) {
                        TextEditor(text: $introduction)
                            .frame(minHeight: 64)
                            .padding(4)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            .scrollContentBackground(.hidden)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent(String(localized: "exhibitions.exhibitItems", defaultValue: "전시품목")) {
                        TextEditor(text: $exhibitItems)
                            .frame(minHeight: 64)
                            .padding(4)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            .scrollContentBackground(.hidden)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section {
                    LabeledContent(String(localized: "exhibitions.organizer", defaultValue: "주최")) {
                        TextField("", text: $organizer)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent(String(localized: "exhibitions.supervisor", defaultValue: "주관")) {
                        TextField("", text: $supervisor)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent(String(localized: "exhibitions.contact", defaultValue: "연락처")) {
                        TextField("", text: $contact)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent(String(localized: "exhibitions.homepage", defaultValue: "홈페이지")) {
                        TextField("", text: $homepage)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(String(localized: "action.cancel"), role: .cancel) {
                    dismiss()
                }
                Button(String(localized: "action.add", defaultValue: "추가")) {
                    addPreset()
                }
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 620)
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
    }

    private func addPreset() {
        let preset = ExhibitionPreset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: max(endDate, startDate),
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            organizer: organizer.trimmingCharacters(in: .whitespacesAndNewlines),
            field: exhibitItems.trimmingCharacters(in: .whitespacesAndNewlines),
            introduction: introduction.trimmingCharacters(in: .whitespacesAndNewlines),
            exhibitItems: exhibitItems.trimmingCharacters(in: .whitespacesAndNewlines),
            supervisor: supervisor.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
            homepage: homepage.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(preset)
        try? context.save()
        Task { await CalendarReminderSyncService.shared.syncEvent(for: preset) }
        dismiss()
    }
}
