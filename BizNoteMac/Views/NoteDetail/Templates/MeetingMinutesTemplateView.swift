import SwiftUI
import Contacts

struct MeetingMinutesTemplateView: View {
    @Binding var data: MeetingMinutesTemplateData
    let businessCards: [BusinessCard]
    @State private var showLocationPicker = false
    @State private var showTaskForm = false
    @AppStorage("general.enableTaskSections") private var enableTaskSections: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Toggle(String(localized: "template.meeting.online", defaultValue: "온라인"),
                       isOn: $data.isOnlineMeeting)
                    .fixedSize()
                if data.isOnlineMeeting {
                    TextField(String(localized: "template.meeting.onlineLink", defaultValue: "회의 링크 (Zoom, Teams 등)"),
                              text: $data.onlineLink)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 2)
                } else {
                    TextField(String(localized: "template.meeting.location"), text: $data.location)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 2)
                    Button(String(localized: "location.picker.title", defaultValue: "위치찾기")) {
                        showLocationPicker = true
                    }
                    .frame(minWidth: 96)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle(String(localized: "template.meeting.participants"))
                    VStack(spacing: 10) {
                        ForEach($data.participants) { $person in
                            participantRow($person)
                        }
                        Button {
                            data.participants.append(.init())
                        } label: {
                            Label(String(localized: "template.meeting.participants.add",
                                         defaultValue: "참석자 추가"), systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle(String(localized: "template.meeting.agenda"))
                    AutoHeightTextEditor(text: $data.agenda, minHeight: 60)
                        .padding(6)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        .scrollContentBackground(.hidden)

                    Divider()

                    sectionTitle(String(localized: "template.meeting.discussion"))
                    ListEditorView(items: $data.discussionPoints,
                                   placeholder: String(localized: "template.meeting.discussion.placeholder"))

                    Divider()

                    sectionTitle(String(localized: "template.meeting.decisions"))
                    ListEditorView(items: $data.decisions,
                                   placeholder: String(localized: "template.meeting.decisions.placeholder"))
                }
                .padding(.vertical, 4)
            }

            if enableTaskSections {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(String(localized: "template.meeting.actionItems"))
                        VStack(spacing: 10) {
                            ForEach($data.actionItems) { $item in
                                actionItemRow($item)
                            }
                            if showTaskForm {
                                TaskFormView(
                                    assigneeSuggestions: participantNames,
                                    onSave: { result in
                                        addActionItem(from: result)
                                        showTaskForm = false
                                    },
                                    onCancel: { showTaskForm = false }
                                )
                            } else {
                                Button {
                                    showTaskForm = true
                                } label: {
                                    Label(String(localized: "template.meeting.action.add"), systemImage: "plus")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(
                initialName: data.location,
                onConfirm: { name, lat, lon in
                    data.location = name
                    data.locationLatitude = lat
                    data.locationLongitude = lon
                    showLocationPicker = false
                },
                onCancel: { showLocationPicker = false }
            )
        }
    }

    private var participantNames: [String] {
        let names = data.participants.map(\.name).filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.callout.weight(.semibold))
    }

    @ViewBuilder
    private func actionItemRow(_ item: Binding<MeetingMinutesTemplateData.ActionItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: item.isCompleted)
                    .labelsHidden()
                    .toggleStyle(.circleCheck(fillColor: NoteCategory.meetingMinutes.accentColor))
                Picker("", selection: item.category) {
                    ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { c in
                        Label(c.localizedName, systemImage: c.systemImage).tag(c)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                TextField(String(localized: "template.meeting.action.task"), text: item.task)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                Text(item.wrappedValue.assignees.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)
                DatePicker("", selection: item.dueDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                Button {
                    data.actionItems.removeAll { $0.id == item.wrappedValue.id }
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain)
            }
            if !item.wrappedValue.detail.isEmpty {
                Text(item.wrappedValue.detail)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func addActionItem(from result: TaskFormResult) {
        var item = MeetingMinutesTemplateData.ActionItem()
        item.task = result.description
        item.detail = result.detail
        item.category = result.category
        item.assignees = result.assignees
        item.dueDate = result.dueDate
        data.actionItems.append(item)
    }

    @ViewBuilder
    private func participantRow(_ person: Binding<MeetingMinutesTemplateData.Participant>) -> some View {
        HStack {
            TextField(String(localized: "template.meeting.participants.name", defaultValue: "이름"),
                      text: person.name)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 2)
            TextField(String(localized: "card.field.jobTitle", defaultValue: "직급"),
                      text: person.jobTitle)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 2)
            TextField(String(localized: "template.meeting.participants.company", defaultValue: "소속"),
                      text: person.company)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 2)
            CardLinkButton(cards: businessCards, onSelect: { card in applyCard(card, to: person) })
            ContactPickerButton(onSelect: { contact in applyContact(contact, to: person) },
                                title: String(localized: "contacts.import.short", defaultValue: "주소록"))
            Button {
                data.participants.removeAll { $0.id == person.wrappedValue.id }
            } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func applyContact(_ contact: CNContact, to person: Binding<MeetingMinutesTemplateData.Participant>) {
        person.wrappedValue.name = contact.displayName
        person.wrappedValue.company = contact.organizationName
        person.wrappedValue.jobTitle = contact.jobTitle
        person.wrappedValue.phone = contact.primaryPhone
        person.wrappedValue.email = contact.primaryEmail
    }

    private func applyCard(_ card: BusinessCard, to person: Binding<MeetingMinutesTemplateData.Participant>) {
        person.wrappedValue.name = card.name
        person.wrappedValue.company = card.company
        person.wrappedValue.jobTitle = card.jobTitle
        person.wrappedValue.phone = card.phone
        person.wrappedValue.email = card.email
        person.wrappedValue.linkedCardID = card.id
    }
}

struct ListEditorView: View {
    @Binding var items: [String]
    let placeholder: String

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Text("•").foregroundStyle(.secondary)
                    TextField(placeholder, text: Binding(
                        get: { items.indices.contains(i) ? items[i] : "" },
                        set: { if items.indices.contains(i) { items[i] = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                    Button {
                        if items.indices.contains(i) { items.remove(at: i) }
                    } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.plain)
                }
            }
            Button {
                items.append("")
            } label: {
                Label(String(localized: "list.add"), systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
