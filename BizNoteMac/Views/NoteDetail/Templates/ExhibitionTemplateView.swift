import SwiftUI
import SwiftData
import Contacts

struct ExhibitionTemplateView: View {
    @Binding var data: ExhibitionTemplateData
    let businessCards: [BusinessCard]
    @Query(sort: \ExhibitionPreset.startDate, order: .reverse) private var presets: [ExhibitionPreset]
    @State private var showTaskForm = false
    @State private var showPresetPicker = false
    @AppStorage("general.enableTaskSections") private var enableTaskSections: Bool = true

    static let worldCountryNames: [String] = {
        let locale = Locale.current
        let names = Locale.Region.isoRegions.compactMap { locale.localizedString(forRegionCode: $0.identifier) }
        return Array(Set(names)).sorted()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField(String(localized: "template.exhibition.name", defaultValue: "행사 이름"), text: $data.exhibitionName)
                    .textFieldStyle(.roundedBorder)
                Button(String(localized: "template.exhibition.loadPreset", defaultValue: "행사 조회")) {
                    showPresetPicker = true
                }
                .frame(minWidth: 96)
            }

            HStack {
                Text(String(localized: "template.exhibition.eventDate", defaultValue: "행사 일자"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $data.eventStartDate, displayedComponents: .date)
                    .labelsHidden()
                Text("–")
                DatePicker("", selection: $data.eventEndDate, displayedComponents: .date)
                    .labelsHidden()
            }

            TextField(String(localized: "template.exhibition.venue"), text: $data.venue)
                .textFieldStyle(.roundedBorder)

            TextField(String(localized: "template.exhibition.organizer"), text: $data.organizer)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(String(localized: "template.exhibition.participationType", defaultValue: "참가 형태"))
                    .font(.callout.weight(.semibold))
                Picker("", selection: $data.participationType) {
                    ForEach(ExhibitionTemplateData.ParticipationType.allCases) { t in
                        Text(t.localizedName).tag(t)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            if data.participationType == .visitor {
                visitedBoothsSection
            } else {
                contactsSection
            }

            if enableTaskSections {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(String(localized: "template.meeting.actionItems"))
                        VStack(spacing: 10) {
                            ForEach($data.tasks) { $task in
                                taskRow($task)
                            }
                            if showTaskForm {
                                TaskFormView(
                                    assigneeSuggestions: assigneeOptions,
                                    onSave: { result in
                                        addTask(from: result)
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
        .sheet(isPresented: $showPresetPicker) {
            ExhibitionPresetListSheet(
                presets: presets,
                onSelect: { preset in
                    applyPreset(preset)
                    showPresetPicker = false
                },
                onCancel: { showPresetPicker = false }
            )
        }
    }

    private var assigneeOptions: [String] {
        let names = data.participationType == .visitor
            ? data.visitedBooths.map(\.contactPerson)
            : data.contacts.map(\.name)
        return Array(Set(names.filter { !$0.isEmpty })).sorted()
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.callout.weight(.semibold))
    }

    @ViewBuilder
    private func taskRow(_ task: Binding<ExhibitionTemplateData.TaskItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: task.isCompleted)
                    .labelsHidden()
                    .toggleStyle(.circleCheck(fillColor: NoteCategory.exhibition.accentColor))
                Picker("", selection: task.category) {
                    ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { c in
                        Label(c.localizedName, systemImage: c.systemImage).tag(c)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                TextField(String(localized: "template.meeting.action.task"), text: task.title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                Text(task.wrappedValue.assignees.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)
                DatePicker("", selection: task.dueDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                Button {
                    data.tasks.removeAll { $0.id == task.wrappedValue.id }
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain)
            }
            if !task.wrappedValue.detail.isEmpty {
                Text(task.wrappedValue.detail)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func addTask(from result: TaskFormResult) {
        var task = ExhibitionTemplateData.TaskItem()
        task.title = result.description
        task.detail = result.detail
        task.category = result.category
        task.assignees = result.assignees
        task.dueDate = result.dueDate
        data.tasks.append(task)
    }

    private var visitedBoothsSection: some View {
        GroupBox(String(localized: "template.exhibition.booths")) {
            VStack(spacing: 8) {
                ForEach($data.visitedBooths) { $booth in
                    boothRow($booth)
                }
                Button {
                    data.visitedBooths.append(.init())
                } label: {
                    Label(String(localized: "template.exhibition.booth.add", defaultValue: "사람 추가"), systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func boothRow(_ booth: Binding<ExhibitionTemplateData.VisitedBooth>) -> some View {
        VStack(spacing: 6) {
            HStack {
                TextField(String(localized: "template.meeting.participants.name", defaultValue: "이름"),
                          text: booth.contactPerson)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                TextField(String(localized: "card.field.jobTitle", defaultValue: "직급"),
                          text: booth.jobTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                TextField(String(localized: "template.exhibition.visitedBooth.company", defaultValue: "회사"),
                          text: booth.companyName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                CardLinkButton(cards: businessCards, onSelect: { card in applyCard(card, toBooth: booth) })
                ContactPickerButton(onSelect: { contact in applyContact(contact, toBooth: booth) },
                                    title: String(localized: "contacts.import.short", defaultValue: "주소록"))
                Button {
                    data.visitedBooths.removeAll { $0.id == booth.wrappedValue.id }
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain)
            }
            HStack {
                TextField(String(localized: "template.exhibition.booth.contactPhone", defaultValue: "연락처"),
                          text: booth.contactPhone)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "template.exhibition.booth.contactEmail", defaultValue: "이메일"),
                          text: booth.contactEmail)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .top, spacing: 6) {
                Text(String(localized: "template.exhibition.contact.memo", defaultValue: "메모"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                AutoHeightTextEditor(text: booth.notes, minHeight: 22)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private var contactsSection: some View {
        GroupBox(String(localized: "template.exhibition.contacts", defaultValue: "만난 사람")) {
            VStack(spacing: 8) {
                ForEach($data.contacts) { $contact in
                    VStack(spacing: 6) {
                        HStack {
                            TextField(String(localized: "template.meeting.participants.name", defaultValue: "이름"),
                                      text: $contact.name)
                                .textFieldStyle(.roundedBorder)
                                .padding(.vertical, 2)
                            TextField(String(localized: "card.field.jobTitle", defaultValue: "직급"),
                                      text: $contact.jobTitle)
                                .textFieldStyle(.roundedBorder)
                                .padding(.vertical, 2)
                            Picker(String(localized: "template.exhibition.contact.country", defaultValue: "국가"),
                                   selection: $contact.country) {
                                Text(String(localized: "settings.iCloud.destination.none", defaultValue: "선택 안 함")).tag("")
                                ForEach(Self.worldCountryNames, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            CardLinkButton(cards: businessCards, onSelect: { card in applyCard(card, toContact: $contact) })
                            ContactPickerButton(onSelect: { c in applyContact(c, toContact: $contact) },
                                                title: String(localized: "contacts.import.short", defaultValue: "주소록"))
                            Button {
                                data.contacts.removeAll { $0.id == contact.id }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                        }
                        TextField(String(localized: "template.exhibition.booth.company", defaultValue: "회사명"),
                                  text: $contact.company)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            TextField(String(localized: "template.exhibition.booth.contactPhone", defaultValue: "연락처"),
                                      text: $contact.phone)
                                .textFieldStyle(.roundedBorder)
                            TextField(String(localized: "template.exhibition.booth.contactEmail", defaultValue: "이메일"),
                                      text: $contact.email)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Text(String(localized: "template.exhibition.contact.memo", defaultValue: "메모"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                            AutoHeightTextEditor(text: $contact.memo, minHeight: 22)
                                .padding(4)
                                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                Button {
                    data.contacts.append(.init())
                } label: {
                    Label(String(localized: "template.exhibition.contacts.add", defaultValue: "사람 추가"), systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }

    private func applyPreset(_ preset: ExhibitionPreset) {
        data.exhibitionName = preset.name
        data.eventStartDate = preset.startDate
        data.eventEndDate = preset.endDate
        data.venue = preset.venue
        data.organizer = preset.organizer
        data.participatingDate = preset.startDate
        data.presetID = preset.id
    }

    private func applyContact(_ contact: CNContact, toBooth booth: Binding<ExhibitionTemplateData.VisitedBooth>) {
        booth.wrappedValue.contactPerson = contact.displayName
        booth.wrappedValue.companyName = contact.organizationName
        booth.wrappedValue.jobTitle = contact.jobTitle
        booth.wrappedValue.contactPhone = contact.primaryPhone
        booth.wrappedValue.contactEmail = contact.primaryEmail
    }

    private func applyContact(_ contact: CNContact, toContact target: Binding<ExhibitionTemplateData.Contact>) {
        target.wrappedValue.name = contact.displayName
        target.wrappedValue.company = contact.organizationName
        target.wrappedValue.jobTitle = contact.jobTitle
        target.wrappedValue.phone = contact.primaryPhone
        target.wrappedValue.email = contact.primaryEmail
    }

    private func applyCard(_ card: BusinessCard, toBooth booth: Binding<ExhibitionTemplateData.VisitedBooth>) {
        booth.wrappedValue.contactPerson = card.name
        booth.wrappedValue.companyName = card.company
        booth.wrappedValue.jobTitle = card.jobTitle
        booth.wrappedValue.contactPhone = card.phone
        booth.wrappedValue.contactEmail = card.email
        booth.wrappedValue.linkedCardID = card.id
    }

    private func applyCard(_ card: BusinessCard, toContact target: Binding<ExhibitionTemplateData.Contact>) {
        target.wrappedValue.name = card.name
        target.wrappedValue.company = card.company
        target.wrappedValue.jobTitle = card.jobTitle
        target.wrappedValue.phone = card.phone
        target.wrappedValue.email = card.email
        target.wrappedValue.linkedCardID = card.id
    }
}

/// A separate window (sheet) listing the registered events, shown when
/// the event-name field's 행사 조회 button is clicked.
private struct ExhibitionPresetListSheet: View {
    let presets: [ExhibitionPreset]
    var onSelect: (ExhibitionPreset) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "template.exhibition.loadPreset", defaultValue: "행사 조회"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "action.cancel"), action: onCancel)
                    .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            if presets.isEmpty {
                Text(String(localized: "template.exhibition.noPresets", defaultValue: "등록된 행사가 없습니다"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(presets) { preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name).font(.callout.weight(.semibold))
                            Text(preset.dateRangeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 360, height: 420)
    }
}
