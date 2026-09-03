import SwiftUI
import SwiftData

struct ExportSheetView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case notes, businessCards, all
        var id: String { rawValue }
        var localized: String {
            switch self {
            case .notes:         return String(localized: "export.kind.notes")
            case .businessCards: return String(localized: "export.kind.cards")
            case .all:           return String(localized: "export.kind.all", defaultValue: "모두")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Query private var allNotes: [Note]
    @Query private var allCards: [BusinessCard]
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var kind: Kind = .notes
    @State private var categoryFilter: NoteCategorySelection? = nil
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @AppStorage("export.openAfterSave") private var openAfterSave: Bool = true
    @AppStorage("export.cardFormat") private var cardFormatRaw: String = SpreadsheetFormat.xlsx.rawValue

    private var cardFormat: SpreadsheetFormat {
        SpreadsheetFormat(rawValue: cardFormatRaw) ?? .xlsx
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "export.title"))
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "export.targetLabel", defaultValue: "대상"))
                    .font(.callout.weight(.semibold))
                Picker("", selection: $kind) {
                    ForEach(Kind.allCases) { k in
                        Text(k.localized).tag(k)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if kind != .businessCards {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "export.noteListLabel", defaultValue: "노트목록"))
                        .font(.callout.weight(.semibold))
                    Picker("", selection: $categoryFilter) {
                        Text(String(localized: "export.category.all")).tag(NoteCategorySelection?.none)
                        ForEach(NoteCategory.allCases) { c in
                            Text(c.localizedName).tag(NoteCategorySelection?.some(.builtin(c)))
                        }
                        ForEach(customCategories) { c in
                            Text(c.name).tag(NoteCategorySelection?.some(.custom(c)))
                        }
                    }
                    .labelsHidden()
                }
            }

            if kind != .notes {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "export.cardFormat", defaultValue: "명함 파일 형식"))
                        .font(.callout.weight(.semibold))
                    Picker("", selection: $cardFormatRaw) {
                        ForEach(SpreadsheetFormat.allCases) { f in
                            Text(f.localizedName).tag(f.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "export.periodLabel", defaultValue: "기간"))
                    .font(.callout.weight(.semibold))
                HStack {
                    DatePicker(String(localized: "export.startDate"),
                               selection: $startDate, displayedComponents: .date)
                    DatePicker(String(localized: "export.endDate"),
                               selection: $endDate, displayedComponents: .date)
                }
            }

            Toggle(String(localized: "export.openAfterSave"), isOn: $openAfterSave)
                .toggleStyle(.switch)

            HStack {
                Text(String(localized: "export.count") + ": \(filteredCount)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "action.cancel")) { dismiss() }
                Button(String(localized: "export.run")) {
                    performExport()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(filteredCount == 0)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var filteredNotes: [Note] {
        allNotes.filter { note in
            let inRange = note.updatedAt >= startOfDay(startDate) && note.updatedAt <= endOfDay(endDate)
            let matches: Bool = {
                guard let categoryFilter else { return true }
                switch categoryFilter {
                case .builtin(let c): return !note.isCustomCategory && note.category == c
                case .custom(let c):  return note.isCustomCategory && note.customCategory?.id == c.id
                }
            }()
            return inRange && matches
        }
    }

    private var filteredCards: [BusinessCard] {
        allCards.filter { $0.createdAt >= startOfDay(startDate) && $0.createdAt <= endOfDay(endDate) }
    }

    private var filteredCount: Int {
        switch kind {
        case .notes:         return filteredNotes.count
        case .businessCards: return filteredCards.count
        case .all:           return filteredNotes.count + filteredCards.count
        }
    }

    private func performExport() {
        switch kind {
        case .notes:
            PDFExportService.exportNotes(filteredNotes, openAfter: openAfterSave)
        case .businessCards:
            ExcelExportService.exportBusinessCards(filteredCards, format: cardFormat, openAfter: openAfterSave)
        case .all:
            PDFExportService.exportNotes(filteredNotes, openAfter: openAfterSave)
            ExcelExportService.exportBusinessCards(filteredCards, format: cardFormat, openAfter: openAfterSave)
        }
    }

    private func startOfDay(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }
    private func endOfDay(_ d: Date) -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: d) ?? d
    }
}
