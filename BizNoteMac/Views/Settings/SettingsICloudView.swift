import SwiftUI
import SwiftData
import AppKit

struct SettingsICloudView: View {
    @ObservedObject private var sync = CloudSyncService.shared
    @Environment(\.modelContext) private var context
    @Query private var exhibitionPresets: [ExhibitionPreset]
    @Query private var notes: [Note]
    @AppStorage("icloud.syncNotesEnabled") private var syncNotesEnabled: Bool = true
    @AppStorage("icloud.syncBackupEnabled") private var syncBackupEnabled: Bool = true
    @AppStorage("integration.syncEventsWithCalendar") private var syncEventsWithCalendar: Bool = false
    @AppStorage("integration.syncTasksWithReminders") private var syncTasksWithReminders: Bool = false
    @AppStorage("integration.selectedEventCalendarIdentifier") private var selectedEventCalendarIdentifier: String = ""
    @AppStorage("integration.selectedReminderListIdentifier") private var selectedReminderListIdentifier: String = ""

    @State private var showDeleteConfirmation = false
    @State private var showDeleteFinalConfirmation = false
    @State private var eventCalendars: [CalendarReminderSyncService.Destination] = []
    @State private var reminderLists: [CalendarReminderSyncService.Destination] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(String(localized: "settings.iCloud.sync", defaultValue: "iCloud 동기화")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.iCloud.syncNotes", defaultValue: "노트 동기화"))
                            Text(String(localized: "settings.iCloud.syncNotes.hint",
                                        defaultValue: "노트와 명함 데이터를 iCloud를 통해 기기 간에 동기화합니다."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $syncNotesEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.iCloud.syncBackup", defaultValue: "백업 동기화"))
                            Text(String(localized: "settings.iCloud.syncBackup.hint",
                                        defaultValue: "명함 이미지 등 첨부 파일을 iCloud Drive에 백업합니다."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $syncBackupEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox(String(localized: "settings.iCloud.appleApps", defaultValue: "Apple 앱 연동")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.iCloud.syncEventsWithCalendar",
                                        defaultValue: "행사를 캘린더 앱과 동기화"))
                            Text(String(localized: "settings.iCloud.syncEventsWithCalendar.hint",
                                        defaultValue: "선택한 iCloud 캘린더에 행사 일정이 추가됩니다."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker(String(localized: "settings.iCloud.eventCalendar", defaultValue: "추가할 캘린더"),
                               selection: $selectedEventCalendarIdentifier) {
                            Text(String(localized: "settings.iCloud.destination.none", defaultValue: "선택 안 함")).tag("")
                            ForEach(eventCalendars) { calendar in
                                Text(destinationTitle(calendar)).tag(calendar.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 160)
                        .disabled(!syncEventsWithCalendar || eventCalendars.isEmpty)
                        Toggle("", isOn: $syncEventsWithCalendar)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.iCloud.syncTasksWithReminders",
                                        defaultValue: "업무를 미리알림 앱과 동기화"))
                            Text(String(localized: "settings.iCloud.syncTasksWithReminders.hint",
                                        defaultValue: "선택한 iCloud 미리알림 리스트에 업무 항목이 추가됩니다."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker(String(localized: "settings.iCloud.reminderList", defaultValue: "추가할 리스트"),
                               selection: $selectedReminderListIdentifier) {
                            Text(String(localized: "settings.iCloud.destination.none", defaultValue: "선택 안 함")).tag("")
                            ForEach(reminderLists) { list in
                                Text(destinationTitle(list)).tag(list.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 160)
                        .disabled(!syncTasksWithReminders || reminderLists.isEmpty)
                        Toggle("", isOn: $syncTasksWithReminders)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "settings.iCloud.deleteAll", defaultValue: "iCloud 데이터 전체 삭제"),
                              systemImage: "trash")
                    }
                    Text(String(localized: "settings.iCloud.deleteAll.hint",
                                defaultValue: "모든 노트, 명함, 전시회 정보를 이 기기와 iCloud에서 삭제합니다."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            HStack {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(String(localized: "settings.iCloud.openSystemSettings"),
                          systemImage: "gear")
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: sync.status.iconName)
                            .foregroundStyle(iconColor)
                        Text(sync.status.localizedLabel)
                    }
                    if let d = sync.lastSyncDate {
                        HStack(spacing: 4) {
                            Text(String(localized: "settings.iCloud.lastSync"))
                                .foregroundStyle(.secondary)
                            Text(d, format: .dateTime.year().month().day().hour().minute())
                        }
                        .font(.caption)
                    }
                }
            }

            Text(String(localized: "settings.iCloud.restartHint",
                        defaultValue: "동기화 설정 변경 사항은 앱을 재시작하면 적용됩니다."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(4)
        .confirmationDialog(
            String(localized: "settings.iCloud.deleteAll.confirm.title", defaultValue: "iCloud 데이터를 모두 삭제할까요?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.iCloud.deleteAll.confirm.action", defaultValue: "삭제"), role: .destructive) {
                showDeleteFinalConfirmation = true
            }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.iCloud.deleteAll.confirm.message",
                        defaultValue: "모든 노트, 명함, 전시회 정보가 이 기기와 iCloud에서 삭제됩니다. 이 작업은 되돌릴 수 없습니다."))
        }
        .alert(
            String(localized: "settings.iCloud.deleteAll.final.title", defaultValue: "정말 삭제하시겠습니까?"),
            isPresented: $showDeleteFinalConfirmation
        ) {
            Button(String(localized: "settings.iCloud.deleteAll.confirm.action", defaultValue: "삭제"), role: .destructive) {
                deleteAllData()
            }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.iCloud.deleteAll.final.message", defaultValue: "삭제 후에는 복구할 수 없습니다."))
        }
        .task {
            await refreshDestinations(requestAccess: false)
        }
        .onChange(of: syncEventsWithCalendar) { _, enabled in
            guard enabled else { return }
            Task {
                await refreshEventCalendars(requestAccess: true)
                await syncExistingEvents()
            }
        }
        .onChange(of: syncTasksWithReminders) { _, enabled in
            guard enabled else { return }
            Task {
                await refreshReminderLists(requestAccess: true)
                await syncExistingTasks()
            }
        }
        .onChange(of: selectedEventCalendarIdentifier) { _, _ in
            guard syncEventsWithCalendar else { return }
            Task { await syncExistingEvents() }
        }
        .onChange(of: selectedReminderListIdentifier) { _, _ in
            guard syncTasksWithReminders else { return }
            Task { await syncExistingTasks() }
        }
    }

    private var iconColor: Color {
        switch sync.status {
        case .idle:    return .secondary
        case .syncing: return .accentColor
        case .success: return .green
        case .error:   return .red
        }
    }

    /// Deletes every locally-stored record. Since this app mirrors its
    /// SwiftData store to CloudKit, deleting locally propagates the deletion
    /// to the iCloud container through the normal sync mechanism — this is
    /// the safe way to empty it without touching CloudKit zones directly
    /// (which could conflict with SwiftData's own zone management).
    private func deleteAllData() {
        try? context.delete(model: Note.self)
        try? context.delete(model: BusinessCard.self)
        try? context.delete(model: CustomCategory.self)
        try? context.delete(model: ExhibitionPreset.self)
        try? context.save()
    }

    private func destinationTitle(_ destination: CalendarReminderSyncService.Destination) -> String {
        "\(destination.title) (\(destination.sourceTitle))"
    }

    private func refreshDestinations(requestAccess: Bool) async {
        await refreshEventCalendars(requestAccess: requestAccess && syncEventsWithCalendar)
        await refreshReminderLists(requestAccess: requestAccess && syncTasksWithReminders)
    }

    private func refreshEventCalendars(requestAccess: Bool) async {
        eventCalendars = await CalendarReminderSyncService.shared.eventCalendars(requestAccess: requestAccess)
        if selectedEventCalendarIdentifier.isEmpty, let first = eventCalendars.first {
            selectedEventCalendarIdentifier = first.id
        } else if !selectedEventCalendarIdentifier.isEmpty,
                  !eventCalendars.contains(where: { $0.id == selectedEventCalendarIdentifier }) {
            selectedEventCalendarIdentifier = eventCalendars.first?.id ?? ""
        }
    }

    private func refreshReminderLists(requestAccess: Bool) async {
        reminderLists = await CalendarReminderSyncService.shared.reminderLists(requestAccess: requestAccess)
        if selectedReminderListIdentifier.isEmpty, let first = reminderLists.first {
            selectedReminderListIdentifier = first.id
        } else if !selectedReminderListIdentifier.isEmpty,
                  !reminderLists.contains(where: { $0.id == selectedReminderListIdentifier }) {
            selectedReminderListIdentifier = reminderLists.first?.id ?? ""
        }
    }

    private func syncExistingEvents() async {
        for preset in exhibitionPresets {
            await CalendarReminderSyncService.shared.syncEvent(for: preset)
        }
        try? context.save()
    }

    private func syncExistingTasks() async {
        var changed = false

        for note in notes where !note.isCustomCategory {
            switch note.category {
            case .workLog:
                guard var data = TemplateCoder.decode(WorkLogTemplateData.self, from: note.templateData) else { continue }
                let synced = await syncWorkLogItems(data.workItems, dueDate: data.date)
                if synced != data.workItems {
                    data.workItems = synced
                    note.templateData = TemplateCoder.encode(data)
                    changed = true
                }
            case .meetingMinutes:
                guard var data = TemplateCoder.decode(MeetingMinutesTemplateData.self, from: note.templateData) else { continue }
                let synced = await syncMeetingItems(data.actionItems)
                if synced != data.actionItems {
                    data.actionItems = synced
                    note.templateData = TemplateCoder.encode(data)
                    changed = true
                }
            case .exhibition:
                guard var data = TemplateCoder.decode(ExhibitionTemplateData.self, from: note.templateData) else { continue }
                let synced = await syncExhibitionItems(data.tasks)
                if synced != data.tasks {
                    data.tasks = synced
                    note.templateData = TemplateCoder.encode(data)
                    changed = true
                }
            }
        }

        if changed {
            try? context.save()
        }
    }

    private func syncWorkLogItems(
        _ items: [WorkLogTemplateData.WorkItem],
        dueDate: Date
    ) async -> [WorkLogTemplateData.WorkItem] {
        var synced = items
        for index in synced.indices {
            let item = synced[index]
            let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                title: item.task,
                detail: item.status.localizedName,
                assignees: [],
                dueDate: dueDate,
                isCompleted: item.status == .done,
                existingIdentifier: item.reminderIdentifier
            )
            synced[index].reminderIdentifier = reminderID
        }
        return synced
    }

    private func syncMeetingItems(
        _ items: [MeetingMinutesTemplateData.ActionItem]
    ) async -> [MeetingMinutesTemplateData.ActionItem] {
        var synced = items
        for index in synced.indices {
            let item = synced[index]
            let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                title: item.task,
                detail: item.detail,
                assignees: item.assignees,
                dueDate: item.dueDate,
                isCompleted: item.isCompleted,
                existingIdentifier: item.reminderIdentifier
            )
            synced[index].reminderIdentifier = reminderID
        }
        return synced
    }

    private func syncExhibitionItems(
        _ items: [ExhibitionTemplateData.TaskItem]
    ) async -> [ExhibitionTemplateData.TaskItem] {
        var synced = items
        for index in synced.indices {
            let item = synced[index]
            let reminderID = await CalendarReminderSyncService.shared.syncReminder(
                title: item.title,
                detail: item.detail,
                assignees: item.assignees,
                dueDate: item.dueDate,
                isCompleted: item.isCompleted,
                existingIdentifier: item.reminderIdentifier
            )
            synced[index].reminderIdentifier = reminderID
        }
        return synced
    }
}
