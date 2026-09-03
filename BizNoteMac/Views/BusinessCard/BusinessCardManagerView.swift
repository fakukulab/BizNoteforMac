import SwiftUI
import SwiftData

/// Backs the "명함 관리" smart folder — lists every business card scanned
/// across all notes (meeting minutes, exhibitions, and custom note lists;
/// work log no longer supports scanning). Selecting a card shows its scanned
/// image and an editable form in the detail column.
struct BusinessCardManagerView: View {
    @Binding var selectedCard: BusinessCard?
    @Environment(\.modelContext) private var context
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]

    @AppStorage("export.openAfterSave") private var openAfterSave: Bool = true
    @AppStorage("export.cardFormat") private var cardFormatRaw: String = SpreadsheetFormat.xlsx.rawValue

    @State private var noteTypeFilter: CardNoteTypeFilter = .all
    @State private var dateSort: CardDateSort = .newestFirst
    @State private var isSelectionMode = false
    @State private var selectedCardIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    private var cardFormat: SpreadsheetFormat {
        SpreadsheetFormat(rawValue: cardFormatRaw) ?? .xlsx
    }

    private var visibleCards: [BusinessCard] {
        cards
            .filter(matchesNoteType)
            .sorted { lhs, rhs in
                switch dateSort {
                case .newestFirst:
                    return lhs.createdAt > rhs.createdAt
                case .oldestFirst:
                    return lhs.createdAt < rhs.createdAt
                }
            }
    }

    private var hasCustomCards: Bool {
        cards.contains { $0.note?.isCustomCategory == true }
    }

    private var filteredCardIDs: Set<UUID> {
        Set(visibleCards.map(\.id))
    }

    private var actionCards: [BusinessCard] {
        if isSelectionMode {
            return visibleCards.filter { selectedCardIDs.contains($0.id) }
        }
        guard let selectedCard else { return [] }
        return [selectedCard]
    }

    var body: some View {
        VStack(spacing: 0) {
            controls

            Divider()

            Group {
                if cards.isEmpty {
                    EmptyStateView(
                        systemImage: "person.text.rectangle",
                        title: String(localized: "cardManager.empty.title", defaultValue: "스캔된 명함이 없습니다"),
                        message: String(localized: "cardManager.empty.message",
                                         defaultValue: "회의록이나 전시회 노트에서 명함을 스캔하면 여기에 표시됩니다.")
                    )
                } else if visibleCards.isEmpty {
                    EmptyStateView(
                        systemImage: "line.3.horizontal.decrease.circle",
                        title: String(localized: "cardManager.filtered.empty.title", defaultValue: "조건에 맞는 명함이 없습니다"),
                        message: String(localized: "cardManager.filtered.empty.message", defaultValue: "노트 종류 또는 일자 정렬 조건을 변경해 보세요.")
                    )
                } else if isSelectionMode {
                    List(visibleCards, id: \.id, selection: $selectedCardIDs) { card in
                        cardRow(card).tag(card.id)
                    }
                    .listStyle(.inset)
                } else {
                    List(visibleCards, id: \.id, selection: $selectedCard) { card in
                        cardRow(card).tag(card)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(String(localized: "sidebar.businessCards"))
        .alert(deleteTitle, isPresented: $showDeleteConfirmation) {
            Button(String(localized: "action.cancel"), role: .cancel) {}
            Button(String(localized: "action.delete", defaultValue: "삭제"), role: .destructive) {
                deleteActionCards()
            }
        } message: {
            Text(String(localized: "cardManager.delete.message", defaultValue: "명함 정보와 저장된 명함 이미지가 함께 삭제됩니다."))
        }
        .onChange(of: noteTypeFilter) { _, _ in
            reconcileSelectionWithVisibleCards()
        }
        .onChange(of: dateSort) { _, _ in
            reconcileSelectionWithVisibleCards()
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(availableNoteTypeFilters) { filter in
                    Button {
                        noteTypeFilter = filter
                    } label: {
                        Label(filter.localizedName, systemImage: filter.systemImage)
                    }
                }
            } label: {
                CircularToolbarIcon(systemName: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .help(String(localized: "cardManager.filter.noteType", defaultValue: "노트종류 필터"))

            Menu {
                ForEach(CardDateSort.allCases) { sort in
                    Button {
                        dateSort = sort
                    } label: {
                        Label(sort.localizedName, systemImage: sort.systemImage)
                    }
                }
            } label: {
                CircularToolbarIcon(systemName: dateSort.systemImage)
            }
            .menuStyle(.borderlessButton)
            .help(String(localized: "cardManager.sort.date", defaultValue: "일자 정렬"))

            Button {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selectedCardIDs.removeAll()
                }
            } label: {
                CircularToolbarIcon(
                    systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle",
                    isActive: isSelectionMode
                )
            }
            .buttonStyle(.plain)
            .help(String(localized: "cardManager.selection.toggle", defaultValue: "명함 선택"))

            Text(toolbarStatusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirmation = !actionCards.isEmpty
            } label: {
                CircularToolbarIcon(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(actionCards.isEmpty)
            .help(String(localized: "action.delete", defaultValue: "삭제"))

            Button {
                exportActionCards()
            } label: {
                CircularToolbarIcon(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(actionCards.isEmpty)
            .help(String(localized: "action.export", defaultValue: "내보내기"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

    }

    private var availableNoteTypeFilters: [CardNoteTypeFilter] {
        var filters: [CardNoteTypeFilter] = [.all, .meetingMinutes, .exhibition]
        if hasCustomCards {
            filters.append(.custom)
        }
        return filters
    }

    private var toolbarStatusText: String {
        if isSelectionMode {
            return String(format: String(localized: "cardManager.selection.count", defaultValue: "%d개 선택"), selectedCardIDs.count)
        }
        return String(format: String(localized: "cardManager.count", defaultValue: "%d개 표시"), visibleCards.count)
    }

    private var deleteTitle: String {
        let count = actionCards.count
        if count <= 1 {
            return String(localized: "cardManager.delete.title", defaultValue: "선택한 명함을 삭제할까요?")
        }
        return String(format: String(localized: "cardManager.delete.multiple.title", defaultValue: "%d개의 명함을 삭제할까요?"), count)
    }

    private func cardRow(_ card: BusinessCard) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if isSelectionMode {
                Button {
                    toggleSelection(for: card)
                } label: {
                    Image(systemName: selectedCardIDs.contains(card.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedCardIDs.contains(card.id) ? Color.accentColor : Color.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(String(localized: "cardManager.selection.toggle", defaultValue: "명함 선택"))
            }

            Image(systemName: "person.text.rectangle.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.name.isEmpty ? String(localized: "note.untitled") : card.name)
                    .font(.headline)
                if !card.company.isEmpty || !card.jobTitle.isEmpty {
                    Text([card.company, card.jobTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !card.email.isEmpty {
                    Text(card.email).font(.caption2).foregroundStyle(.tertiary)
                }
                if !card.phone.isEmpty {
                    Text(card.phone).font(.caption2).foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    if let note = card.note {
                        Image(systemName: note.categoryIconName)
                        Text(note.title.isEmpty ? note.categoryName : note.title)
                    } else {
                        Image(systemName: "questionmark.folder")
                        Text(String(localized: "cardManager.note.none", defaultValue: "연결된 노트 없음"))
                    }
                    Spacer(minLength: 0)
                    Text(card.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption2)
                .foregroundStyle(card.note?.categoryAccentColor ?? .secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func matchesNoteType(_ card: BusinessCard) -> Bool {
        switch noteTypeFilter {
        case .all:
            return true
        case .meetingMinutes:
            return card.note?.isCustomCategory == false && card.note?.category == .meetingMinutes
        case .exhibition:
            return card.note?.isCustomCategory == false && card.note?.category == .exhibition
        case .custom:
            return card.note?.isCustomCategory == true
        }
    }

    private func toggleSelection(for card: BusinessCard) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    private func deleteActionCards() {
        let cardsToDelete = actionCards
        guard !cardsToDelete.isEmpty else { return }

        for card in cardsToDelete {
            AttachmentStorage.removeCardImage(path: card.imagePath)
            context.delete(card)
        }

        if let selectedCard, cardsToDelete.contains(where: { $0.id == selectedCard.id }) {
            self.selectedCard = nil
        }
        selectedCardIDs.subtract(cardsToDelete.map(\.id))
        try? context.save()
    }

    private func exportActionCards() {
        let cardsToExport = actionCards
        guard !cardsToExport.isEmpty else { return }
        ExcelExportService.exportBusinessCards(cardsToExport, format: cardFormat, openAfter: openAfterSave)
    }

    private func reconcileSelectionWithVisibleCards() {
        selectedCardIDs = selectedCardIDs.intersection(filteredCardIDs)
        guard let selectedCard, !visibleCards.contains(where: { $0.id == selectedCard.id }) else { return }
        self.selectedCard = nil
    }
}

private enum CardNoteTypeFilter: String, Identifiable {
    case all
    case meetingMinutes
    case exhibition
    case custom

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .all:
            return String(localized: "export.category.all", defaultValue: "전체")
        case .meetingMinutes:
            return NoteCategory.meetingMinutes.localizedName
        case .exhibition:
            return NoteCategory.exhibition.localizedName
        case .custom:
            return String(localized: "cardManager.filter.custom", defaultValue: "사용자 목록")
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "tray.full"
        case .meetingMinutes:
            return NoteCategory.meetingMinutes.systemIconName
        case .exhibition:
            return NoteCategory.exhibition.systemIconName
        case .custom:
            return "folder.fill"
        }
    }
}

private enum CardDateSort: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .newestFirst:
            return String(localized: "cardManager.sort.newest", defaultValue: "최신순")
        case .oldestFirst:
            return String(localized: "cardManager.sort.oldest", defaultValue: "오래된순")
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst:
            return "arrow.down"
        case .oldestFirst:
            return "arrow.up"
        }
    }
}
