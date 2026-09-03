import SwiftUI
import AppKit

struct CustomNoteTemplateView: View {
    @Binding var data: CustomNoteTemplateData
    @Binding var attachmentPaths: [String]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach($data.sections) { $section in
                CustomNoteSectionView(
                    section: $section,
                    attachmentPaths: $attachmentPaths,
                    openEventWindow: { openWindow(id: "new-exhibition") }
                )
            }
        }
    }
}

private struct CustomNoteSectionView: View {
    @Binding var section: CustomNoteTemplateSection
    @Binding var attachmentPaths: [String]
    let openEventWindow: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: section.kind.systemImage)
                        .foregroundStyle(.secondary)
                    Text(section.title.isEmpty ? section.kind.defaultTitle : section.title)
                        .font(.callout.weight(.semibold))
                }
                content
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section.kind {
        case .taskBoard:
            taskBoard
        case .achievement, .work:
            TextEditor(text: $section.text)
                .frame(minHeight: 70)
                .padding(6)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .scrollContentBackground(.hidden)
        case .attachments:
            attachmentsSection
        case .participants:
            participantsSection
        case .addEvent:
            Button {
                openEventWindow()
            } label: {
                Label(String(localized: "exhibitions.add", defaultValue: "행사 추가"), systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private var taskBoard: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(CustomNoteTask.Status.allCases) { status in
                taskColumn(for: status)
            }
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func taskColumn(for status: CustomNoteTask.Status) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.localizedName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                ForEach($section.tasks) { $task in
                    if task.status == status {
                        taskRow($task)
                    }
                }
            }
            Button {
                section.tasks.append(CustomNoteTask(status: status))
            } label: {
                Label(String(localized: "template.workLog.item.add"), systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private func taskRow(_ task: Binding<CustomNoteTask>) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Menu {
                ForEach(CustomNoteTask.Status.allCases) { status in
                    Button(status.localizedName) {
                        task.wrappedValue.status = status
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            TextField(String(localized: "template.workLog.item.placeholder"), text: task.title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .lineLimit(1...)

            Button {
                section.tasks.removeAll { $0.id == task.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attachmentPaths, id: \.self) { path in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.secondary)
                    Text(AttachmentStorage.attachmentDisplayName(path: path))
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        AttachmentStorage.openAttachment(path: path)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.plain)
                    Button {
                        AttachmentStorage.removeAttachment(path: path)
                        attachmentPaths.removeAll { $0 == path }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            Button {
                addAttachment()
            } label: {
                Label(String(localized: "template.workLog.attachments.add", defaultValue: "파일 추가"), systemImage: "paperclip")
            }
            .buttonStyle(.borderless)
        }
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($section.participants) { $participant in
                HStack(spacing: 8) {
                    TextField(String(localized: "template.meeting.participant.name", defaultValue: "이름"), text: $participant.name)
                        .textFieldStyle(.roundedBorder)
                    TextField(String(localized: "template.meeting.participant.company", defaultValue: "회사"), text: $participant.company)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        section.participants.removeAll { $0.id == participant.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                section.participants.append(CustomNoteParticipant())
            } label: {
                Label(String(localized: "template.meeting.participants.add", defaultValue: "참석자 추가"), systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private func addAttachment() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let path = AttachmentStorage.saveAttachment(from: url) {
                attachmentPaths.append(path)
            }
        }
    }
}
