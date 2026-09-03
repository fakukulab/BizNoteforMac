import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedCategory: SidebarSelection? = .allNotes
    @State private var selectedNote: Note? = nil
    @State private var selectedCard: BusinessCard? = nil
    @State private var selectedPreset: ExhibitionPreset? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCardInspector: Bool = false
    @State private var searchText: String = ""
    @State private var showExportSheet: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedCategory)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            if selectedCategory == .exhibitions {
                ExhibitionManagerView(selectedPreset: $selectedPreset)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
            } else if selectedCategory == .businessCards {
                BusinessCardManagerView(selectedCard: $selectedCard)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            } else {
                NoteListView(
                    selection: selectedCategory,
                    selectedNote: $selectedNote,
                    searchText: $searchText,
                    onCreateNote: createNote,
                    onCreateLegacyNote: createNote
                )
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
            }
        } detail: {
            if selectedCategory == .exhibitions {
                if let preset = selectedPreset {
                    ExhibitionDetailView(preset: preset)
                } else {
                    EmptyStateView(
                        systemImage: "building.columns",
                        title: String(localized: "empty.selectExhibition.title", defaultValue: "행사를 선택하세요"),
                        message: String(localized: "empty.selectExhibition.message",
                                         defaultValue: "행사 리스트에서 항목을 선택하면 세부 정보가 표시됩니다.")
                    )
                }
            } else if selectedCategory == .businessCards {
                if let card = selectedCard {
                    BusinessCardDetailView(card: card)
                } else {
                    EmptyStateView(
                        systemImage: "person.text.rectangle",
                        title: String(localized: "empty.selectCard.title", defaultValue: "명함을 선택하세요"),
                        message: String(localized: "empty.selectCard.message",
                                         defaultValue: "왼쪽 목록에서 명함을 선택하면 세부 정보가 표시됩니다.")
                    )
                }
            } else if let note = selectedNote {
                Group {
                    if showsCardPanel(note) {
                        NoteDetailView(note: note)
                            .inspector(isPresented: $showCardInspector) {
                                BusinessCardPanelView(note: note)
                                    .inspectorColumnWidth(min: 300, ideal: 360, max: 460)
                            }
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        showCardInspector.toggle()
                                    } label: {
                                        Label(String(localized: "menu.toggleInspector"),
                                              systemImage: "person.text.rectangle")
                                    }
                                    .help("⌘⌥I")
                                }
                            }
                    } else {
                        NoteDetailView(note: note)
                    }
                }
                .id(note.id)
            } else {
                EmptyStateView(
                    systemImage: "note.text",
                    title: String(localized: "empty.selectNote.title"),
                    message: String(localized: "empty.selectNote.message")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequested)) { _ in
            createNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInspectorRequested)) { _ in
            showCardInspector.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importCardRequested)) { _ in
            if selectedNote == nil { createNote() }
            if let note = selectedNote, showsCardPanel(note) {
                showCardInspector = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categorySelectRequested)) { note in
            if let cat = note.object as? NoteCategory {
                selectedCategory = .builtin(cat)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportRequested)) { _ in
            showExportSheet = true
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheetView()
        }
    }

    /// Business card scanning is only offered for meeting minutes, exhibition,
    /// and custom note lists — work log notes use plain file attachments instead.
    private func showsCardPanel(_ note: Note) -> Bool {
        note.isCustomCategory || note.category != .workLog
    }

    private func createNote(request: NoteCreationRequest) {
        let note = Note(title: request.title, category: request.category, content: "")
        note.templateData = request.templateData
        insertAndSelect(note)
    }

    private func createNote(category requestedCategory: NoteCategory? = nil) {
        let note: Note
        if let requestedCategory {
            note = Note(title: "", category: requestedCategory, content: "")
        } else if case .builtin(let category) = selectedCategory {
            note = Note(title: "", category: category, content: "")
        } else if case .custom(let category) = selectedCategory {
            note = Note(title: "", customCategory: category, content: "")
            note.templateData = category.templateData
        } else {
            note = Note(title: "", category: .workLog, content: "")
        }
        insertAndSelect(note)
    }

    private func insertAndSelect(_ note: Note) {
        context.insert(note)
        try? context.save()
        selectedNote = note
    }
}

enum SidebarSelection: Hashable {
    case allNotes
    case favorites
    case recent
    case businessCards
    case exhibitions
    case builtin(NoteCategory)
    case custom(CustomCategory)
}
