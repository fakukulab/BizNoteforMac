import SwiftUI

/// The result of filling out `TaskFormView`, mapped by the caller into either
/// a `MeetingMinutesTemplateData.ActionItem` or an `ExhibitionTemplateData.TaskItem`.
struct TaskFormResult {
    var description: String
    var detail: String
    var dueDate: Date
    var category: ExhibitionTemplateData.TaskItem.TaskCategory
    var assignees: [String]
}

private enum DuePreset: String, CaseIterable, Identifiable {
    case today, tomorrow, nextWeek, custom
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .today:    return String(localized: "template.taskForm.due.today", defaultValue: "Today")
        case .tomorrow: return String(localized: "template.taskForm.due.tomorrow", defaultValue: "Tomorrow")
        case .nextWeek: return String(localized: "template.taskForm.due.nextWeek", defaultValue: "Next week")
        case .custom:   return String(localized: "template.taskForm.due.custom", defaultValue: "Custom")
        }
    }
}

private enum AssigneeInputMode: String {
    case none, myself, custom
}

/// A shared "add task" form used by both the meeting-minutes 업무/Task list
/// and the exhibition 업무/Task list, since both sections manage a nearly
/// identical shape (description, due date/time, category, assignees).
/// Rendered inline in the page (not a popover/sheet) by whichever section
/// shows it.
struct TaskFormView: View {
    var assigneeSuggestions: [String]
    var onSave: (TaskFormResult) -> Void
    var onCancel: () -> Void

    @State private var description: String = ""
    @State private var showDetail: Bool = false
    @State private var detail: String = ""

    @State private var duePreset: DuePreset = .today
    @State private var dueDate: Date = Date()

    @State private var hour: Int = 9
    @State private var minute: Int = 0
    @State private var isPM: Bool = false

    @State private var category: ExhibitionTemplateData.TaskItem.TaskCategory = .call

    @State private var assignees: [String] = []
    @State private var assigneeInputMode: AssigneeInputMode = .none
    @State private var newAssigneeName: String = ""
    @State private var syncedCustomAssigneeName: String = ""

    private let hours = Array(1...12)
    private let minutes = Array(stride(from: 0, to: 60, by: 5))

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            descriptionSection
            combinedRow
            actionButtons
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Sections

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                fieldLabel(String(localized: "template.taskForm.description", defaultValue: "내용"))
                Spacer()
                Button(String(localized: "template.taskForm.addDetail", defaultValue: "Add more detail")) {
                    showDetail.toggle()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            TextField("", text: $description)
                .textFieldStyle(.roundedBorder)
            if showDetail {
                TextEditor(text: $detail)
                    .frame(minHeight: 50)
                    .padding(4)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    .scrollContentBackground(.hidden)
            }
        }
    }

    private var combinedRow: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(String(localized: "template.taskForm.category", defaultValue: "Category"))
                Picker("", selection: $category) {
                    ForEach(ExhibitionTemplateData.TaskItem.TaskCategory.selectableCases) { c in
                        Label(c.localizedName, systemImage: c.systemImage).tag(c)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(String(localized: "template.taskForm.due", defaultValue: "Due"))
                HStack {
                    Picker("", selection: $duePreset) {
                        ForEach(DuePreset.allCases) { preset in
                            Text(preset.localizedName).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: duePreset) { _, preset in applyDuePreset(preset) }
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(String(localized: "template.taskForm.time", defaultValue: "Time"))
                HStack(spacing: 4) {
                    Picker("", selection: $hour) {
                        ForEach(hours, id: \.self) { h in Text("\(h)").tag(h) }
                    }
                    .labelsHidden()
                    .frame(width: 50)
                    Text(":")
                    Picker("", selection: $minute) {
                        ForEach(minutes, id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                    }
                    .labelsHidden()
                    .frame(width: 60)
                    Picker("", selection: $isPM) {
                        Text(String(localized: "template.taskForm.am", defaultValue: "AM")).tag(false)
                        Text(String(localized: "template.taskForm.pm", defaultValue: "PM")).tag(true)
                    }
                    .labelsHidden()
                    .frame(width: 60)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(String(localized: "template.taskForm.assignee", defaultValue: "Assigned to"))
                HStack(spacing: 6) {
                    Menu {
                        Button(String(localized: "template.taskForm.assignee.myself", defaultValue: "자신")) {
                            assigneeInputMode = .myself
                            clearCustomAssignee()
                            addAssignee(String(localized: "template.taskForm.assignee.myself", defaultValue: "자신"))
                        }
                        Button(String(localized: "template.taskForm.assignee.placeholder", defaultValue: "이름 입력")) {
                            assigneeInputMode = .custom
                        }
                    } label: {
                        Label(assigneeMenuTitle, systemImage: "person.crop.circle.badge.plus")
                    }
                    .frame(width: 140, alignment: .leading)

                    if assigneeInputMode == .custom {
                        TextField(String(localized: "template.taskForm.assignee.placeholder", defaultValue: "이름 입력"),
                                  text: $newAssigneeName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onChange(of: newAssigneeName) { _, newValue in
                                syncCustomAssignee(newValue)
                            }
                    }

                    if !assignees.isEmpty {
                        assigneeChips
                    }
                }
            }
        }
    }

    private var assigneeMenuTitle: String {
        switch assigneeInputMode {
        case .myself:
            return String(localized: "template.taskForm.assignee.myself", defaultValue: "자신")
        case .custom:
            return String(localized: "template.taskForm.assignee.placeholder", defaultValue: "이름 입력")
        case .none:
            return String(localized: "template.taskForm.assignee.select", defaultValue: "담당자 선택")
        }
    }

    private var assigneeChips: some View {
        HStack(spacing: 4) {
            ForEach(assignees, id: \.self) { name in
                HStack(spacing: 4) {
                    Text(name)
                        .lineLimit(1)
                    Button {
                        removeAssignee(name)
                    } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button(String(localized: "action.cancel"), action: onCancel)
                .frame(minWidth: 80)
            Button(String(localized: "action.save")) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 80)
            .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.defaultAction)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.callout.weight(.semibold))
    }

    private func applyDuePreset(_ preset: DuePreset) {
        switch preset {
        case .today:    dueDate = Date()
        case .tomorrow: dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case .nextWeek: dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        case .custom:   break
        }
    }

    @discardableResult
    private func addAssignee(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !assignees.contains(trimmed) else { return false }
        assignees.append(trimmed)
        return true
    }

    private func removeAssignee(_ name: String) {
        assignees.removeAll { $0 == name }
        if syncedCustomAssigneeName == name {
            syncedCustomAssigneeName = ""
            newAssigneeName = ""
        }
    }

    private func syncCustomAssignee(_ name: String) {
        if !syncedCustomAssigneeName.isEmpty {
            assignees.removeAll { $0 == syncedCustomAssigneeName }
            syncedCustomAssigneeName = ""
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if addAssignee(trimmed) {
            syncedCustomAssigneeName = trimmed
        }
    }

    private func clearCustomAssignee() {
        if !syncedCustomAssigneeName.isEmpty {
            assignees.removeAll { $0 == syncedCustomAssigneeName }
            syncedCustomAssigneeName = ""
        }
        newAssigneeName = ""
    }

    private func combinedDueDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = isPM ? (hour % 12) + 12 : hour % 12
        components.minute = minute
        return calendar.date(from: components) ?? dueDate
    }

    private func save() {
        if assigneeInputMode == .custom {
            syncCustomAssignee(newAssigneeName)
        }
        let result = TaskFormResult(
            description: description.trimmingCharacters(in: .whitespaces),
            detail: detail,
            dueDate: combinedDueDate(),
            category: category,
            assignees: assignees
        )
        onSave(result)
    }
}
