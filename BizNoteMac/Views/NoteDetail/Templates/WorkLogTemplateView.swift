import SwiftUI
import AppKit

struct WorkLogTemplateView: View {
    @Binding var data: WorkLogTemplateData
    @Binding var attachmentPaths: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "template.workLog.items", defaultValue: "업무"))
                    .font(.callout.weight(.semibold))
                HStack(alignment: .top, spacing: 12) {
                    workItemColumn(for: .todo)
                    workItemColumn(for: .inProgress)
                    workItemColumn(for: .done)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            labeledEditor(String(localized: "template.workLog.achievements"), text: $data.achievements)
            labeledEditor(String(localized: "template.workLog.issues"), text: $data.issues)
            labeledEditor(String(localized: "template.workLog.nextTodos"), text: $data.nextTodos)

            attachmentsSection
        }
    }

    @ViewBuilder
    private func workItemColumn(for status: WorkLogTemplateData.WorkItem.TaskStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.localizedName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                ForEach($data.workItems) { $item in
                    if item.status == status {
                        workItemRow($item)
                    }
                }
            }
            Button {
                data.workItems.append(.init(status: status))
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

    @ViewBuilder
    private func workItemRow(_ item: Binding<WorkLogTemplateData.WorkItem>) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Menu {
                ForEach(WorkLogTemplateData.WorkItem.TaskStatus.allCases, id: \.self) { s in
                    Button(s.localizedName) { updateStatus(item, to: s) }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            AutoHeightTextEditor(text: item.task, minHeight: 20)
                .font(.caption)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                .onChange(of: item.wrappedValue.task) { _, _ in
                    syncAchievementIfNeeded(item)
                }

            Button {
                data.workItems.removeAll { $0.id == item.wrappedValue.id }
            } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func updateStatus(
        _ item: Binding<WorkLogTemplateData.WorkItem>,
        to newStatus: WorkLogTemplateData.WorkItem.TaskStatus
    ) {
        item.wrappedValue.status = newStatus
        syncAchievementIfNeeded(item)
    }

    /// Completed work items are mirrored into the achievements field so finishing a
    /// task doesn't require re-typing it into the achievements section by hand. Since
    /// the task text keeps changing while the user types, this keeps replacing the
    /// item's previously-written line rather than writing it once and locking,
    /// which used to freeze the copy at whatever text existed after the first keystroke.
    private func syncAchievementIfNeeded(_ item: Binding<WorkLogTemplateData.WorkItem>) {
        guard item.wrappedValue.status == .done else { return }
        let line = item.wrappedValue.task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        if let previous = item.wrappedValue.lastSyncedAchievementText {
            guard previous != line else { return }
            if let range = data.achievements.range(of: previous) {
                data.achievements.replaceSubrange(range, with: line)
            } else {
                data.achievements = data.achievements.isEmpty ? line : data.achievements + "\n" + line
            }
        } else {
            data.achievements = data.achievements.isEmpty ? line : data.achievements + "\n" + line
        }
        item.wrappedValue.lastSyncedAchievementText = line
    }

    @ViewBuilder
    private func labeledEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.semibold))
            TextEditor(text: text)
                .frame(minHeight: 60)
                .padding(6)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .scrollContentBackground(.hidden)
        }
    }

    private var attachmentsSection: some View {
        GroupBox(String(localized: "template.workLog.attachments", defaultValue: "첨부파일")) {
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
                        .help(String(localized: "template.workLog.attachments.open", defaultValue: "파일 열기"))
                        Button {
                            removeAttachment(path)
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                Button {
                    addAttachment()
                } label: {
                    Label(String(localized: "template.workLog.attachments.add", defaultValue: "파일 추가"),
                          systemImage: "paperclip")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
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

    private func removeAttachment(_ path: String) {
        AttachmentStorage.removeAttachment(path: path)
        attachmentPaths.removeAll { $0 == path }
    }
}
