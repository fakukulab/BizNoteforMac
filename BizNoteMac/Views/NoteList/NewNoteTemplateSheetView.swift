import SwiftUI

struct NoteCreationRequest {
    let title: String
    let category: NoteCategory
    let templateData: String
}

struct NewNoteTemplateSheetView: View {
    let initialCategory: NoteCategory
    let onCancel: () -> Void
    let onSave: (NoteCreationRequest) -> Void

    @State private var noteTitle: String
    @State private var selectedCategory: NoteCategory

    init(
        initialCategory: NoteCategory,
        onCancel: @escaping () -> Void,
        onSave: @escaping (NoteCreationRequest) -> Void
    ) {
        self.initialCategory = initialCategory
        self.onCancel = onCancel
        self.onSave = onSave
        _noteTitle = State(initialValue: "")
        _selectedCategory = State(initialValue: initialCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            NewNoteSheetHeader()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "note.new.name", defaultValue: "노트 이름"))
                    .font(.callout.weight(.semibold))
                TextField(String(localized: "note.title.placeholder"), text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "note.new.template", defaultValue: "템플릿"))
                    .font(.callout.weight(.semibold))

                VStack(spacing: 8) {
                    ForEach(NoteCategory.allCases) { category in
                        NewNoteTemplateOptionRow(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(String(localized: "action.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "action.save", defaultValue: "저장")) {
                    onSave(
                        NoteCreationRequest(
                            title: trimmedTitle,
                            category: selectedCategory,
                            templateData: selectedCategory.defaultTemplateData
                        )
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460)
        .frame(minHeight: 430)
    }

    private var trimmedTitle: String {
        noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct NewNoteSheetHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "note.new.title", defaultValue: "새 노트 추가"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "note.new.message", defaultValue: "노트 이름을 입력하고 앞으로 사용할 템플릿을 선택하세요."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NewNoteTemplateOptionRow: View {
    let category: NoteCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? category.accentColor : Color.secondary)
                    .font(.title3)
                    .frame(width: 24, height: 24)

                Image(systemName: category.systemIconName)
                    .foregroundStyle(category.accentColor)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.localizedName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(category.templateSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.accentColor : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.localizedName)
    }
}

private extension NoteCategory {
    var defaultTemplateData: String {
        switch self {
        case .workLog:
            return TemplateCoder.encode(WorkLogTemplateData())
        case .meetingMinutes:
            return TemplateCoder.encode(MeetingMinutesTemplateData())
        case .exhibition:
            return TemplateCoder.encode(ExhibitionTemplateData())
        }
    }

    var templateSummary: String {
        switch self {
        case .workLog:
            return String(localized: "note.new.template.workLog.summary", defaultValue: "업무 항목, 성과, 이슈, 다음 할 일을 기록합니다.")
        case .meetingMinutes:
            return String(localized: "note.new.template.meeting.summary", defaultValue: "참석자, 안건, 논의 내용, 결정 사항, 액션 아이템을 기록합니다.")
        case .exhibition:
            return String(localized: "note.new.template.exhibition.summary", defaultValue: "행사 정보, 방문 부스, 연락처, 후속 태스크를 기록합니다.")
        }
    }
}
