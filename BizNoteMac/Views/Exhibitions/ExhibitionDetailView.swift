import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Shown in the rightmost detail column when an event is selected from the
/// 행사 리스트 — an editable detail view for registered exhibition details.
struct ExhibitionDetailView: View {
    @Bindable var preset: ExhibitionPreset
    @Environment(\.modelContext) private var context

    @State private var draft = ExhibitionDraft()
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ExhibitionHeaderEditor(
                        draft: $draft,
                        isEditing: isEditing,
                        logoImage: logoImage,
                        onUploadLogo: uploadLogo,
                        onRemoveLogo: removeLogo
                    )

                    ExhibitionBodyEditor(draft: $draft, isEditing: isEditing)
                }
                .padding(24)
            }

            Divider()

            ExhibitionActionBar(
                isEditing: isEditing,
                canSave: isEditing && draft != ExhibitionDraft(preset: preset),
                onEdit: beginEditing,
                onSave: saveDraft,
                onCancel: cancelEditing
            )
        }
        .navigationTitle(draft.name.isEmpty ? String(localized: "note.untitled") : draft.name)
        .onAppear {
            loadDraft()
        }
        .onChange(of: preset.id) { _, _ in
            loadDraft()
            isEditing = false
        }
    }

    private var logoImage: NSImage? {
        AttachmentStorage.loadExhibitionLogo(path: draft.logoImagePath)
    }

    private func beginEditing() {
        loadDraft()
        isEditing = true
    }

    private func cancelEditing() {
        let currentPath = draft.logoImagePath
        let savedPath = preset.logoImagePath
        if currentPath != savedPath {
            AttachmentStorage.removeExhibitionLogo(path: currentPath)
        }
        loadDraft()
        isEditing = false
    }

    private func loadDraft() {
        draft = ExhibitionDraft(preset: preset)
    }

    private func uploadLogo() {
        guard isEditing else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url),
              let squareImage = image.centeredSquareImage(),
              let savedPath = AttachmentStorage.saveExhibitionLogo(squareImage, id: preset.id) else {
            return
        }

        if draft.logoImagePath != preset.logoImagePath {
            AttachmentStorage.removeExhibitionLogo(path: draft.logoImagePath)
        }
        draft.logoImagePath = savedPath
    }

    private func removeLogo() {
        guard isEditing else { return }

        if draft.logoImagePath != preset.logoImagePath {
            AttachmentStorage.removeExhibitionLogo(path: draft.logoImagePath)
        }
        draft.logoImagePath = ""
    }

    private func saveDraft() {
        let previousLogoPath = preset.logoImagePath

        preset.name = draft.name
        preset.startDate = draft.startDate
        preset.endDate = draft.endDate
        preset.venue = draft.venue
        preset.organizer = draft.organizer
        preset.field = draft.exhibitItems
        preset.introduction = draft.introduction
        preset.exhibitItems = draft.exhibitItems
        preset.supervisor = draft.supervisor
        preset.contact = draft.contact
        preset.homepage = draft.homepage
        preset.logoImagePath = draft.logoImagePath

        if previousLogoPath != draft.logoImagePath {
            AttachmentStorage.removeExhibitionLogo(path: previousLogoPath)
        }

        try? context.save()
        Task { await CalendarReminderSyncService.shared.syncEvent(for: preset) }
        isEditing = false
        loadDraft()
    }
}

private struct ExhibitionDraft: Equatable {
    var name = ""
    var startDate = Date()
    var endDate = Date()
    var venue = ""
    var organizer = ""
    var introduction = ""
    var exhibitItems = ""
    var supervisor = ""
    var contact = ""
    var homepage = ""
    var logoImagePath = ""

    init() { }

    init(preset: ExhibitionPreset) {
        name = preset.name
        startDate = preset.startDate
        endDate = preset.endDate
        venue = preset.venue
        organizer = preset.organizer
        introduction = preset.introduction
        exhibitItems = preset.exhibitItems
        supervisor = preset.supervisor
        contact = preset.contact
        homepage = preset.homepage
        logoImagePath = preset.logoImagePath
    }
}

private struct ExhibitionHeaderEditor: View {
    @Binding var draft: ExhibitionDraft
    let isEditing: Bool
    let logoImage: NSImage?
    let onUploadLogo: () -> Void
    let onRemoveLogo: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ExhibitionImageEditor(
                image: logoImage,
                hasImage: !draft.logoImagePath.isEmpty,
                isEditing: isEditing,
                onUpload: onUploadLogo,
                onRemove: onRemoveLogo
            )

            VStack(alignment: .leading, spacing: 12) {
                EditableTextFieldRow(
                    title: String(localized: "exhibitions.name", defaultValue: "행사명"),
                    text: $draft.name,
                    isEditing: isEditing
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "exhibitions.schedule", defaultValue: "일정"))
                        .font(.callout.weight(.semibold))
                    HStack(spacing: 8) {
                        DatePicker("", selection: $draft.startDate, displayedComponents: .date)
                            .labelsHidden()
                            .disabled(!isEditing)
                        Text("-")
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $draft.endDate, displayedComponents: .date)
                            .labelsHidden()
                            .disabled(!isEditing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                EditableTextFieldRow(
                    title: String(localized: "exhibitions.venue", defaultValue: "장소"),
                    text: $draft.venue,
                    isEditing: isEditing
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExhibitionImageEditor: View {
    let image: NSImage?
    let hasImage: Bool
    let isEditing: Bool
    let onUpload: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 26))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "exhibitions.image.empty", defaultValue: "행사 이미지"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            HStack(spacing: 8) {
                Button(action: onUpload) {
                    Label(String(localized: "exhibitions.image.upload", defaultValue: "이미지 업로드"), systemImage: "photo.badge.plus")
                }
                .disabled(!isEditing)

                if hasImage {
                    Button(role: .destructive, action: onRemove) {
                        Label(String(localized: "exhibitions.image.remove", defaultValue: "이미지 삭제"), systemImage: "trash")
                    }
                    .disabled(!isEditing)
                }
            }
        }
        .frame(width: 180, alignment: .leading)
    }
}

private struct ExhibitionBodyEditor: View {
    @Binding var draft: ExhibitionDraft
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditableTextEditorRow(
                title: String(localized: "exhibitions.introduction", defaultValue: "행사소개"),
                text: $draft.introduction,
                isEditing: isEditing,
                minHeight: 96
            )

            EditableTextEditorRow(
                title: String(localized: "exhibitions.exhibitItems", defaultValue: "전시품목"),
                text: $draft.exhibitItems,
                isEditing: isEditing,
                minHeight: 96
            )

            EditableTextFieldRow(
                title: String(localized: "exhibitions.organizer", defaultValue: "주최"),
                text: $draft.organizer,
                isEditing: isEditing
            )

            EditableTextFieldRow(
                title: String(localized: "exhibitions.supervisor", defaultValue: "주관"),
                text: $draft.supervisor,
                isEditing: isEditing
            )

            EditableTextFieldRow(
                title: String(localized: "exhibitions.contact", defaultValue: "연락처"),
                text: $draft.contact,
                isEditing: isEditing
            )

            HomepageEditorRow(
                homepage: $draft.homepage,
                isEditing: isEditing
            )
        }
    }
}

private struct EditableTextFieldRow: View {
    let title: String
    @Binding var text: String
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EditableTextEditorRow: View {
    let title: String
    @Binding var text: String
    let isEditing: Bool
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
            TextEditor(text: $text)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .padding(4)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                .scrollContentBackground(.hidden)
                .disabled(!isEditing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomepageEditorRow: View {
    @Binding var homepage: String
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "exhibitions.homepage", defaultValue: "홈페이지"))
                .font(.callout.weight(.semibold))
            HStack(spacing: 8) {
                TextField("", text: $homepage)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)

                Link(destination: homepageURL ?? URL(string: "about:blank")!) {
                    Label(String(localized: "exhibitions.homepage.open", defaultValue: "열기"), systemImage: "safari")
                }
                .disabled(homepageURL == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var homepageURL: URL? {
        let trimmed = homepage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

private struct ExhibitionActionBar: View {
    let isEditing: Bool
    let canSave: Bool
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(action: onEdit) {
                Label(String(localized: "action.edit", defaultValue: "수정"), systemImage: "pencil")
            }
            .disabled(isEditing)

            Button(action: onSave) {
                Label(String(localized: "action.save", defaultValue: "저장"), systemImage: "checkmark")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!canSave)

            Button(role: .cancel, action: onCancel) {
                Label(String(localized: "action.cancel", defaultValue: "취소"), systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
            .disabled(!isEditing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
