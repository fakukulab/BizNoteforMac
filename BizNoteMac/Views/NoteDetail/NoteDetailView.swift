import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context

    @State private var workLog: WorkLogTemplateData = .init()
    @State private var meeting: MeetingMinutesTemplateData = .init()
    @State private var exhibition: ExhibitionTemplateData = .init()
    @State private var customTemplate: CustomNoteTemplateData = .init()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Divider()

                templateSection

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "note.freeMemo"))
                        .font(.callout.weight(.semibold))
                    freeMemoField
                }

                Divider()

                TagEditorView(tags: $note.tags)
            }
            .padding(24)
        }
        .navigationTitle(note.title.isEmpty ? String(localized: "note.untitled") : note.title)
        .onAppear(perform: loadTemplate)
        .onChange(of: workLog) { _, new in
            save(template: new)
            updateWorkLogTitleIfNeeded()
            syncWorkLogReminders()
        }
        .onChange(of: meeting) { _, new in
            save(template: new)
            syncMeetingReminders()
        }
        .onChange(of: exhibition) { _, new in
            save(template: new)
            syncExhibitionReminders()
        }
        .onChange(of: customTemplate) { _, new in
            save(template: new)
        }
        .onChange(of: note.title) { _, _ in touch() }
        .onChange(of: note.content) { _, _ in touch() }
        .onChange(of: note.tags) { _, _ in touch() }
        .onChange(of: note.attachmentPaths) { _, _ in touch() }
    }

    private var isWorkLog: Bool { !note.isCustomCategory && note.category == .workLog }
    private var isMeeting: Bool { !note.isCustomCategory && note.category == .meetingMinutes }
    private var isExhibition: Bool { !note.isCustomCategory && note.category == .exhibition }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    note.isFavorite.toggle()
                } label: {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(note.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(note.isFavorite
                                    ? String(localized: "note.unfavorite")
                                    : String(localized: "note.favorite"))

                if isWorkLog {
                    Text(note.title.isEmpty ? String(localized: "note.untitled") : note.title)
                        .font(.largeTitle.weight(.semibold))
                } else {
                    TextField(String(localized: "note.title.placeholder"), text: $note.title)
                        .font(.largeTitle.weight(.semibold))
                        .textFieldStyle(.plain)
                        .accessibilityLabel(String(localized: "note.title.placeholder"))
                }
            }

            HStack(spacing: 10) {
                Label(note.categoryName, systemImage: note.categoryIconName)
                    .foregroundStyle(note.categoryAccentColor)
                    .font(.callout)

                if isMeeting {
                    DatePicker("", selection: $meeting.meetingDate)
                        .labelsHidden()
                        .font(.callout)
                } else if isExhibition {
                    DatePicker("", selection: $exhibition.participatingDate, displayedComponents: .date)
                        .labelsHidden()
                        .font(.callout)
                } else if isWorkLog {
                    DatePicker("", selection: $workLog.date, displayedComponents: .date)
                        .labelsHidden()
                        .font(.callout)
                }

                Spacer()

                Text(note.updatedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var freeMemoField: some View {
        if isWorkLog || isMeeting || isExhibition {
            AutoHeightTextEditor(text: $note.content, minHeight: 40)
                .font(.body)
                .padding(8)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .scrollContentBackground(.hidden)
        } else {
            TextEditor(text: $note.content)
                .font(.body)
                .frame(minHeight: 220)
                .padding(8)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var templateSection: some View {
        if note.isCustomCategory {
            if !customTemplate.sections.isEmpty {
                CustomNoteTemplateView(data: $customTemplate, attachmentPaths: $note.attachmentPaths)
            }
        } else {
            switch note.category {
            case .workLog:
                WorkLogTemplateView(data: $workLog, attachmentPaths: $note.attachmentPaths)
            case .meetingMinutes:
                MeetingMinutesTemplateView(data: $meeting, businessCards: note.businessCards ?? [])
            case .exhibition:
                ExhibitionTemplateView(data: $exhibition, businessCards: note.businessCards ?? [])
            }
        }
    }

    private func loadTemplate() {
        if note.isCustomCategory {
            let storedTemplate = TemplateCoder.decode(CustomNoteTemplateData.self, from: note.templateData)
            let categoryTemplate = note.customCategory.flatMap { TemplateCoder.decode(CustomNoteTemplateData.self, from: $0.templateData) }
            customTemplate = storedTemplate ?? categoryTemplate ?? .init()
            if storedTemplate == nil, let categoryTemplate {
                note.templateData = TemplateCoder.encode(categoryTemplate)
            }
            return
        }
        switch note.category {
        case .workLog:
            workLog = TemplateCoder.decode(WorkLogTemplateData.self, from: note.templateData) ?? .init()
            updateWorkLogTitleIfNeeded()
        case .meetingMinutes:
            meeting = TemplateCoder.decode(MeetingMinutesTemplateData.self, from: note.templateData) ?? .init()
        case .exhibition:
            exhibition = TemplateCoder.decode(ExhibitionTemplateData.self, from: note.templateData) ?? .init()
        }
    }

    private func updateWorkLogTitleIfNeeded() {
        guard isWorkLog, shouldUseAutomaticWorkLogTitle else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: workLog.date)
        let suffix = String(localized: "workLog.title.autoSuffix", defaultValue: "업무일지")
        let newTitle = "\(dateStr) \(suffix)"
        if note.title != newTitle {
            note.title = newTitle
        }
    }

    private var shouldUseAutomaticWorkLogTitle: Bool {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return true }
        let suffix = String(localized: "workLog.title.autoSuffix", defaultValue: "업무일지")
        guard title.hasSuffix(" " + suffix) else { return false }
        let datePrefix = title.prefix(10)
        return datePrefix.count == 10
            && datePrefix.dropFirst(4).first == "-"
            && datePrefix.dropFirst(7).first == "-"
    }

    private func save<T: Codable>(template: T) {
        let encoded = TemplateCoder.encode(template)
        if encoded != note.templateData {
            note.templateData = encoded
            touch()
        }
    }

    private func touch() {
        note.updatedAt = Date()
        try? context.save()
    }

    private func syncWorkLogReminders() {
        for item in workLog.workItems where !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let itemID = item.id
            Task {
                let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                    title: item.task,
                    detail: item.status.localizedName,
                    assignees: [],
                    dueDate: workLog.date,
                    isCompleted: item.status == .done,
                    existingIdentifier: item.reminderIdentifier
                )
                guard let reminderID,
                      let index = workLog.workItems.firstIndex(where: { $0.id == itemID }),
                      workLog.workItems[index].reminderIdentifier != reminderID else { return }
                workLog.workItems[index].reminderIdentifier = reminderID
            }
        }
    }

    private func syncMeetingReminders() {
        for item in meeting.actionItems where !item.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let itemID = item.id
            Task {
                let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                    title: item.task,
                    detail: item.detail,
                    assignees: item.assignees,
                    dueDate: item.dueDate,
                    isCompleted: item.isCompleted,
                    existingIdentifier: item.reminderIdentifier
                )
                guard let reminderID,
                      let index = meeting.actionItems.firstIndex(where: { $0.id == itemID }),
                      meeting.actionItems[index].reminderIdentifier != reminderID else { return }
                meeting.actionItems[index].reminderIdentifier = reminderID
            }
        }
    }

    private func syncExhibitionReminders() {
        for item in exhibition.tasks where !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let itemID = item.id
            Task {
                let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                    title: item.title,
                    detail: item.detail,
                    assignees: item.assignees,
                    dueDate: item.dueDate,
                    isCompleted: item.isCompleted,
                    existingIdentifier: item.reminderIdentifier
                )
                guard let reminderID,
                      let index = exhibition.tasks.firstIndex(where: { $0.id == itemID }),
                      exhibition.tasks[index].reminderIdentifier != reminderID else { return }
                exhibition.tasks[index].reminderIdentifier = reminderID
            }
        }
    }
}
