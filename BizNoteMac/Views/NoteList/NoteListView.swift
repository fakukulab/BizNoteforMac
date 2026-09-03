import SwiftUI
import SwiftData

enum NoteSortOption: String, CaseIterable, Identifiable {
    case updatedDesc, createdDesc, titleAsc
    var id: String { rawValue }
    var localized: String {
        switch self {
        case .updatedDesc: return String(localized: "sort.updatedDesc")
        case .createdDesc: return String(localized: "sort.createdDesc")
        case .titleAsc:    return String(localized: "sort.titleAsc")
        }
    }

    var systemImage: String {
        switch self {
        case .updatedDesc: return "arrow.down"
        case .createdDesc: return "calendar.badge.clock"
        case .titleAsc:    return "textformat.abc"
        }
    }
}

struct NoteListView: View {
    let selection: SidebarSelection?
    @Binding var selectedNote: Note?
    @Binding var searchText: String
    let onCreateNote: (NoteCreationRequest) -> Void
    let onCreateLegacyNote: (NoteCategory?) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @AppStorage("noteSort") private var sortRaw: String = NoteSortOption.updatedDesc.rawValue
    @AppStorage("export.openAfterSave") private var openAfterSave: Bool = true

    @State private var isSelectionMode = false
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var showNewNoteSheet = false
    @State private var pendingDeleteNote: Note? = nil
    @State private var pendingDeleteNotes: [Note] = []

    private var sort: NoteSortOption {
        get { NoteSortOption(rawValue: sortRaw) ?? .updatedDesc }
    }

    private var visibleNoteIDs: Set<UUID> {
        Set(filteredNotes.map(\.id))
    }

    private var actionNotes: [Note] {
        if isSelectionMode {
            return filteredNotes.filter { selectedNoteIDs.contains($0.id) }
        }
        guard let selectedNote, filteredNotes.contains(where: { $0.id == selectedNote.id }) else { return [] }
        return [selectedNote]
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            Divider()

            Group {
                if filteredNotes.isEmpty {
                    EmptyStateView(
                        systemImage: "square.and.pencil",
                        title: String(localized: "empty.noteList.title"),
                        message: String(localized: "empty.noteList.message")
                    )
                } else if isSelectionMode {
                    List(filteredNotes, id: \.id, selection: $selectedNoteIDs) { note in
                        noteRow(note)
                            .tag(note.id)
                            .contextMenu {
                                noteContextMenu(for: note)
                            }
                    }
                    .listStyle(.inset)
                } else {
                    List(filteredNotes, id: \.id, selection: $selectedNote) { note in
                        noteRow(note)
                            .tag(note)
                            .contextMenu {
                                noteContextMenu(for: note)
                            }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .searchable(text: $searchText, prompt: String(localized: "search.prompt"))
        .sheet(isPresented: $showNewNoteSheet) {
            NewNoteTemplateSheetView(initialCategory: defaultNewNoteCategory) {
                showNewNoteSheet = false
            } onSave: { request in
                onCreateNote(request)
                showNewNoteSheet = false
            }
        }
        .confirmationDialog(
            String(localized: "note.delete.confirm.title", defaultValue: "노트를 삭제할까요?"),
            isPresented: Binding(get: { pendingDeleteNote != nil }, set: { if !$0 { pendingDeleteNote = nil } }),
            presenting: pendingDeleteNote
        ) { note in
            Button(String(localized: "note.delete"), role: .destructive) {
                delete(note)
                pendingDeleteNote = nil
            }
            Button(String(localized: "action.cancel"), role: .cancel) {
                pendingDeleteNote = nil
            }
        }
        .confirmationDialog(
            deleteMultipleTitle,
            isPresented: Binding(get: { !pendingDeleteNotes.isEmpty }, set: { if !$0 { pendingDeleteNotes = [] } })
        ) {
            Button(String(localized: "note.delete"), role: .destructive) {
                delete(pendingDeleteNotes)
                pendingDeleteNotes = []
            }
            Button(String(localized: "action.cancel"), role: .cancel) {
                pendingDeleteNotes = []
            }
        }
        .onChange(of: sortRaw) { _, _ in
            reconcileSelectionWithVisibleNotes()
        }
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(NoteSortOption.allCases) { opt in
                    Button {
                        sortRaw = opt.rawValue
                    } label: {
                        Label(opt.localized, systemImage: opt.systemImage)
                    }
                }
            } label: {
                CircularToolbarIcon(systemName: sort.systemImage)
            }
            .menuStyle(.borderlessButton)
            .help(String(localized: "sort.menu"))

            Button {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selectedNoteIDs.removeAll()
                }
            } label: {
                CircularToolbarIcon(
                    systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle",
                    isActive: isSelectionMode
                )
            }
            .buttonStyle(.plain)
            .help(String(localized: "noteList.selection.toggle", defaultValue: "노트 선택"))

            Text(toolbarStatusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button(role: .destructive) {
                if !actionNotes.isEmpty {
                    pendingDeleteNotes = actionNotes
                }
            } label: {
                CircularToolbarIcon(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(actionNotes.isEmpty)
            .help(String(localized: "note.delete"))

            Button {
                exportActionNotes()
            } label: {
                CircularToolbarIcon(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(actionNotes.isEmpty)
            .help(String(localized: "action.export", defaultValue: "내보내기"))

            Button(action: createNoteButtonTapped) {
                CircularToolbarIcon(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .help("⌘N")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

    }

    private var toolbarStatusText: String {
        if isSelectionMode {
            return String(format: String(localized: "noteList.selection.count", defaultValue: "%d개 선택"), selectedNoteIDs.count)
        }
        return String(format: String(localized: "noteList.count", defaultValue: "%d개 표시"), filteredNotes.count)
    }

    private var filteredNotes: [Note] {
        let base: [Note] = {
            guard let selection else { return allNotes }
            switch selection {
            case .allNotes:      return allNotes
            case .favorites:     return allNotes.filter(\.isFavorite)
            case .recent:
                let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return allNotes.filter { $0.updatedAt >= cutoff }
            case .businessCards: return []
            case .exhibitions:   return []
            case .builtin(let c):
                return allNotes.filter { !$0.isCustomCategory && $0.category == c }
            case .custom(let c):
                return allNotes.filter { $0.isCustomCategory && $0.customCategory?.id == c.id }
            }
        }()

        let searched: [Note] = {
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return base }
            return base.filter {
                $0.title.lowercased().contains(q)
                    || $0.content.lowercased().contains(q)
                    || $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }()

        switch sort {
        case .updatedDesc: return searched.sorted { $0.updatedAt > $1.updatedAt }
        case .createdDesc: return searched.sorted { $0.createdAt > $1.createdAt }
        case .titleAsc:    return searched.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    private func noteRow(_ note: Note) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if isSelectionMode {
                Button {
                    toggleSelection(for: note)
                } label: {
                    Image(systemName: selectedNoteIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedNoteIDs.contains(note.id) ? Color.accentColor : Color.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(String(localized: "noteList.selection.toggle", defaultValue: "노트 선택"))
            }

            NoteListRow(note: note)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func noteContextMenu(for note: Note) -> some View {
        Button {
            note.isFavorite.toggle()
            note.updatedAt = Date()
            try? context.save()
        } label: {
            Label(note.isFavorite
                  ? String(localized: "note.unfavorite")
                  : String(localized: "note.favorite"),
                  systemImage: note.isFavorite ? "star.slash" : "star")
        }
        Button {
            duplicate(note)
        } label: {
            Label(String(localized: "note.duplicate"), systemImage: "doc.on.doc")
        }
        Divider()
        Button(role: .destructive) {
            pendingDeleteNote = note
        } label: {
            Label(String(localized: "note.delete"), systemImage: "trash")
        }
    }

    private func toggleSelection(for note: Note) {
        if selectedNoteIDs.contains(note.id) {
            selectedNoteIDs.remove(note.id)
        } else {
            selectedNoteIDs.insert(note.id)
        }
    }

    private func createNoteButtonTapped() {
        if selection == .allNotes || selection == .favorites || selection == .recent || selection == nil {
            showNewNoteSheet = true
        } else if case .builtin(let category) = selection {
            onCreateLegacyNote(category)
        } else {
            onCreateLegacyNote(nil)
        }
    }

    private var defaultNewNoteCategory: NoteCategory {
        .workLog
    }

    private var navigationTitle: String {
        switch selection {
        case .allNotes, .none:  return String(localized: "sidebar.allNotes")
        case .favorites:        return String(localized: "sidebar.favorites")
        case .recent:           return String(localized: "sidebar.recent")
        case .businessCards:    return String(localized: "sidebar.businessCards")
        case .exhibitions:      return String(localized: "sidebar.businessMeetings", defaultValue: "행사 미팅")
        case .builtin(let c):   return c.localizedName
        case .custom(let c):    return c.name
        }
    }

    private var deleteMultipleTitle: String {
        let count = pendingDeleteNotes.count
        if count <= 1 {
            return String(localized: "note.delete.confirm.title", defaultValue: "노트를 삭제할까요?")
        }
        return String(format: String(localized: "note.delete.multiple.title", defaultValue: "%d개의 노트를 삭제할까요?"), count)
    }

    private func duplicate(_ note: Note) {
        let copy = Note(title: note.title + " (copy)", category: note.category, content: note.content)
        copy.tags = note.tags
        copy.templateData = note.templateData
        copy.customCategory = note.customCategory
        copy.categoryRaw = note.categoryRaw
        context.insert(copy)
        try? context.save()
        selectedNote = copy
    }

    private func delete(_ note: Note) {
        delete([note])
    }

    private func delete(_ notes: [Note]) {
        guard !notes.isEmpty else { return }
        for note in notes {
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
            context.delete(note)
        }
        selectedNoteIDs.subtract(notes.map(\.id))
        try? context.save()
    }

    private func exportActionNotes() {
        let notesToExport = actionNotes
        guard !notesToExport.isEmpty else { return }
        PDFExportService.exportNotes(notesToExport, openAfter: openAfterSave)
    }

    private func reconcileSelectionWithVisibleNotes() {
        selectedNoteIDs = selectedNoteIDs.intersection(visibleNoteIDs)
        guard let selectedNote, !filteredNotes.contains(where: { $0.id == selectedNote.id }) else { return }
        self.selectedNote = nil
    }
}

struct NoteListRow: View {
    let note: Note
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: note.categoryIconName)
                .foregroundStyle(note.categoryAccentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(note.title.isEmpty ? String(localized: "note.untitled") : note.title)
                        .font(.headline)
                        .lineLimit(1)
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }
                previewText
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .opacity(note.content.isEmpty ? 0 : 1)
                HStack(spacing: 6) {
                    Text(note.contentDate, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if !note.tags.isEmpty {
                        Text("• " + note.tags.prefix(3).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var previewText: Text {
        Text(note.content.isEmpty ? " " : note.content)
    }
}
