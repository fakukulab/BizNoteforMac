import SwiftUI

/// A lightweight month-grid calendar that marks days falling inside any of
/// the given exhibition date ranges with a small dot. Used at the top of
/// the exhibitions content column. Tapping a marked day reports the
/// exhibition it belongs to via `onSelectEvent`.
struct MonthlyCalendarView: View {
    let events: [(id: UUID, range: ClosedRange<Date>)]

    @Binding var displayedMonth: Date
    var onSelectEvent: ((UUID) -> Void)? = nil
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)

                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 4) {
                ForEach(weeks.indices, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(weeks[row].indices, id: \.self) { col in
                            dayCell(weeks[row][col])
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM"
        return f.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let f = DateFormatter()
        return f.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    }

    private func changeMonth(by delta: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }

    private var weeks: [[Date?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = firstWeekday - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for d in 1...daysInMonth {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: firstOfMonth))
        }
        while days.count % 7 != 0 { days.append(nil) }

        var result: [[Date?]] = []
        var idx = 0
        while idx < days.count {
            result.append(Array(days[idx..<min(idx + 7, days.count)]))
            idx += 7
        }
        return result
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let matches = matchingEventIDs(for: day)
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.caption)
                    .foregroundStyle(calendar.isDateInToday(day) ? Color.white : Color.primary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(calendar.isDateInToday(day) ? Color.accentColor : Color.clear))
                Circle()
                    .fill(matches.isEmpty ? Color.clear : Color.orange)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let firstMatch = matches.first else { return }
                onSelectEvent?(firstMatch)
            }
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 30)
        }
    }

    private func matchingEventIDs(for day: Date) -> [UUID] {
        let start = calendar.startOfDay(for: day)
        return events.filter { $0.range.contains(start) }.map(\.id)
    }
}
