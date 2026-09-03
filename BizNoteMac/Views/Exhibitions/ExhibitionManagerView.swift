import SwiftUI
import SwiftData
import AppKit

struct ExhibitionManagerView: View {
    @Binding var selectedPreset: ExhibitionPreset?
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ExhibitionPreset.startDate) private var presets: [ExhibitionPreset]
    @AppStorage("general.showExhibitionsOnCalendar") private var showCalendar: Bool = true

    @State private var pendingDelete: ExhibitionPreset? = nil
    @State private var displayedCalendarMonth: Date = Date()
    @State private var searchText = ""
    @State private var periodFilter: ExhibitionPeriodFilter = .threeMonths
    @State private var customStartDate = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate = Calendar.current.date(byAdding: .month, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var hoveredPresetID: UUID? = nil

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if showCalendar {
                        MonthlyCalendarView(
                            events: sortedPresets.map {
                                (id: $0.id, range: Calendar.current.startOfDay(for: $0.startDate)...Calendar.current.startOfDay(for: $0.endDate))
                            },
                            displayedMonth: $displayedCalendarMonth,
                            onSelectEvent: { id in
                                guard let preset = sortedPresets.first(where: { $0.id == id }) else { return }
                                selectedPreset = preset
                            }
                        )
                    }

                    searchField
                    periodControls

                    if filteredPresets.isEmpty {
                        EmptyStateView(
                            systemImage: "building.columns",
                            title: String(localized: "exhibitions.empty", defaultValue: "등록된 행사가 없습니다"),
                            message: String(localized: "exhibitions.filtered.empty.message", defaultValue: "검색어나 기간 조건을 변경해 보세요.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(filteredPresets) { preset in
                                presetCard(preset)
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle(String(localized: "sidebar.exhibitions", defaultValue: "행사"))
        .confirmationDialog(
            String(localized: "exhibitions.delete.title", defaultValue: "행사를 삭제할까요?"),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { preset in
            Button(String(localized: "note.delete"), role: .destructive) {
                if selectedPreset?.id == preset.id { selectedPreset = nil }
                Task { await CalendarReminderSyncService.shared.removeEvent(for: preset) }
                context.delete(preset)
                try? context.save()
                pendingDelete = nil
            }
            Button(String(localized: "action.cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text(String(localized: "exhibitions.delete.message", defaultValue: "이 작업은 되돌릴 수 없습니다."))
        }
        .onAppear {
            recalculateEndDate(for: periodFilter)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                openWindow(id: "new-exhibition")
            } label: {
                CircularToolbarIcon(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help(String(localized: "exhibitions.add", defaultValue: "행사 추가"))

            Spacer()

            Button(role: .destructive) {
                pendingDelete = selectedPreset
            } label: {
                CircularToolbarIcon(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(selectedPreset == nil)
            .help(String(localized: "note.delete"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(alignment: .bottomLeading) {
            Text(String(format: String(localized: "exhibitions.count", defaultValue: "%d개 표시"), filteredPresets.count))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .offset(y: 14)
        }
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "search.prompt", defaultValue: "검색"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var periodControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "export.periodLabel", defaultValue: "기간"))
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(ExhibitionPeriodFilter.predefined) { filter in
                    Button {
                        periodFilter = filter
                        recalculateEndDate(for: filter)
                    } label: {
                        Text(filter.localizedName)
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(periodFilter == filter ? Color.black : Color.white)
                            .background(periodFilter == filter ? Color.white : Color.secondary.opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.white.opacity(periodFilter == filter ? 1.0 : 0.75), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(filter.localizedName)
                }
            }

            HStack(spacing: 8) {
                ExhibitionDateField(date: $customStartDate) { newDate in
                    customStartDate = Calendar.current.startOfDay(for: newDate)
                    if let months = periodFilter.months {
                        customEndDate = endDate(from: customStartDate, addingMonths: months)
                    } else if customEndDate < customStartDate {
                        customEndDate = customStartDate
                    }
                }

                Text("-")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                ExhibitionDateField(date: $customEndDate) { newDate in
                    customEndDate = max(Calendar.current.startOfDay(for: newDate), customStartDate)
                    updatePeriodSelectionForManualEndDate()
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: customStartDate) { _, newValue in
            customStartDate = Calendar.current.startOfDay(for: newValue)
            if let months = periodFilter.months {
                customEndDate = endDate(from: customStartDate, addingMonths: months)
            } else if customEndDate < customStartDate {
                customEndDate = customStartDate
            }
        }
    }

    private var sortedPresets: [ExhibitionPreset] {
        presets.sorted {
            if $0.startDate == $1.startDate {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.startDate < $1.startDate
        }
    }

    private var filteredPresets: [ExhibitionPreset] {
        sortedPresets.filter { preset in
            matchesSearch(preset) && matchesPeriod(preset)
        }
    }

    private func presetCard(_ preset: ExhibitionPreset) -> some View {
        let isHovered = hoveredPresetID == preset.id
        let logo = logoImage(for: preset)
        let showsLogo = isHovered && logo != nil

        return Button {
            selectedPreset = preset
            displayedCalendarMonth = preset.startDate
        } label: {
            ZStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(preset.name.isEmpty ? String(localized: "note.untitled") : preset.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 3) {
                        Label(preset.compactDateRangeDescription, systemImage: "calendar")
                        if !preset.venue.isEmpty {
                            Label(preset.venue, systemImage: "mappin.and.ellipse")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .opacity(showsLogo ? 0.12 : 1)

                if let logo, showsLogo {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(selectedPreset?.id == preset.id ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedPreset?.id == preset.id ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredPresetID = preset.id
            } else if hoveredPresetID == preset.id {
                hoveredPresetID = nil
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                pendingDelete = preset
            } label: {
                Label(String(localized: "note.delete"), systemImage: "trash")
            }
        }
    }

    private func logoImage(for preset: ExhibitionPreset) -> NSImage? {
        AttachmentStorage.loadExhibitionLogo(path: preset.logoImagePath)
    }

    private func matchesSearch(_ preset: ExhibitionPreset) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return [
            preset.name,
            preset.venue,
            preset.introduction,
            preset.exhibitItems,
            preset.field,
            preset.organizer,
            preset.supervisor,
            preset.contact,
            preset.homepage
        ]
        .joined(separator: " ")
        .lowercased()
        .contains(query)
    }

    private func matchesPeriod(_ preset: ExhibitionPreset) -> Bool {
        let start = Calendar.current.startOfDay(for: min(customStartDate, customEndDate))
        let endBase = Calendar.current.startOfDay(for: max(customStartDate, customEndDate))
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endBase) ?? endBase
        return preset.startDate <= end && preset.endDate >= start
    }

    private func recalculateEndDate(for filter: ExhibitionPeriodFilter) {
        guard let months = filter.months else { return }
        customEndDate = endDate(from: customStartDate, addingMonths: months)
    }

    private func endDate(from startDate: Date, addingMonths months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: Calendar.current.startOfDay(for: startDate)) ?? startDate
    }

    private func updatePeriodSelectionForManualEndDate() {
        let normalizedEnd = Calendar.current.startOfDay(for: customEndDate)
        if let matchingFilter = ExhibitionPeriodFilter.predefined.first(where: { filter in
            guard let months = filter.months else { return false }
            return Calendar.current.isDate(normalizedEnd, inSameDayAs: endDate(from: customStartDate, addingMonths: months))
        }) {
            periodFilter = matchingFilter
        } else {
            periodFilter = .custom
        }
    }
}

private struct ExhibitionDateField: View {
    @Binding var date: Date
    let onChange: (Date) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(formattedDate)
                    .font(.callout.monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            DatePicker("", selection: Binding(
                get: { date },
                set: { newValue in
                    date = newValue
                    onChange(newValue)
                }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

private enum ExhibitionPeriodFilter: String, CaseIterable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case custom

    static let predefined: [ExhibitionPeriodFilter] = [.oneMonth, .threeMonths, .sixMonths, .oneYear]

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .oneMonth:
            return String(localized: "exhibitions.period.oneMonth", defaultValue: "1개월")
        case .threeMonths:
            return String(localized: "exhibitions.period.threeMonths", defaultValue: "3개월")
        case .sixMonths:
            return String(localized: "exhibitions.period.sixMonths", defaultValue: "6개월")
        case .oneYear:
            return String(localized: "exhibitions.period.oneYear", defaultValue: "1년")
        case .custom:
            return String(localized: "exhibitions.period.custom", defaultValue: "직접 지정")
        }
    }

    var months: Int? {
        switch self {
        case .oneMonth:
            return 1
        case .threeMonths:
            return 3
        case .sixMonths:
            return 6
        case .oneYear:
            return 12
        case .custom:
            return nil
        }
    }
}
