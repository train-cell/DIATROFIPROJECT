import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Status of a specific day in the monthly Orchard view.
public enum OrchardDayStatus: Equatable, Sendable {
    case fullTarget       // Full green apple (target reached >= 100%)
    case partial          // Bitten / red apple (partial completion)
    case restDay          // Seedling / leaf for scheduled rest day
    case emptyPast        // Past day with 0 logs
    case future           // Upcoming day

    public var iconName: String {
        switch self {
        case .fullTarget: return "apple.logo"
        case .partial: return "apple.logo"
        case .restDay: return "leaf.fill"
        case .emptyPast: return "circle.dotted"
        case .future: return "circle"
        }
    }

    public var title: String {
        switch self {
        case .fullTarget: return "Στόχος επετεύχθη"
        case .partial: return "Μερική καταγραφή"
        case .restDay: return "Ημέρα ανάπαυσης"
        case .emptyPast: return "Χωρίς καταγραφή"
        case .future: return "Μελλοντική ημέρα"
        }
    }
}

public struct OrchardDayModel: Identifiable {
    public let id = UUID()
    public let dayNumber: Int
    public let date: Date
    public let status: OrchardDayStatus
    public let eatenKcal: Double
    public let plannedKcal: Double
    public let mealCount: Int
}

/// Monthly Orchard Grid View visualizing daily nutrition completion as a harvest of apples.
public struct OrchardView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMonthDate: Date = Date()
    @State private var selectedDay: OrchardDayModel?

    private let weekdayHeaders = ["Δε", "Τρ", "Τε", "Πε", "Πα", "Σα", "Κυ"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    public init() {}

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: selectedMonthDate).capitalized
    }

    private var daysInMonth: [OrchardDayModel] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonthDate),
              let daysCount = calendar.range(of: .day, in: .month, for: selectedMonthDate)?.count else {
            return []
        }

        let startOfMonth = monthInterval.start
        let today = calendar.startOfDay(for: Date())

        var list: [OrchardDayModel] = []
        for day in 1...daysCount {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let isFuture = date > today
                let isToday = calendar.isDate(date, inSameDayAs: today)

                let status: OrchardDayStatus
                let eaten: Double
                let planned: Double
                let meals: Int

                if isFuture {
                    status = .future
                    eaten = 0
                    planned = 2000
                    meals = 0
                } else if isToday {
                    let progress = container.appleProgress
                    eaten = progress.totalEatenKcal
                    planned = progress.totalPlannedKcal
                    meals = progress.eatenCount
                    if progress.isComplete {
                        status = .fullTarget
                    } else if progress.eatenCount > 0 {
                        status = .partial
                    } else if progress.totalCount == 0 {
                        status = .restDay
                    } else {
                        status = .partial
                    }
                } else {
                    // Historical days simulation / sample deterministic logic based on day
                    if day % 7 == 0 {
                        status = .restDay
                        eaten = 1800
                        planned = 1800
                        meals = 3
                    } else if day % 5 == 0 {
                        status = .partial
                        eaten = 1450
                        planned = 2100
                        meals = 3
                    } else if day % 9 == 0 {
                        status = .emptyPast
                        eaten = 0
                        planned = 2000
                        meals = 0
                    } else {
                        status = .fullTarget
                        eaten = 2150
                        planned = 2100
                        meals = 4
                    }
                }

                list.append(
                    OrchardDayModel(
                        dayNumber: day,
                        date: date,
                        status: status,
                        eatenKcal: eaten,
                        plannedKcal: planned,
                        mealCount: meals
                    )
                )
            }
        }
        return list
    }

    private var leadingPaddingDaysCount: Int {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonthDate) else { return 0 }
        let weekday = calendar.component(.weekday, from: monthInterval.start)
        // In Gregorian: 1 = Sun, 2 = Mon, 3 = Tue, 4 = Wed, 5 = Thu, 6 = Fri, 7 = Sat
        // We want Mon = 0, Tue = 1, Wed = 2, Thu = 3, Fri = 4, Sat = 5, Sun = 6
        return (weekday + 5) % 7
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month Navigation Header
                    monthPickerHeader

                    // Monthly Harvest Summary Cards
                    harvestSummaryCards

                    // Calendar Grid Card
                    calendarGridCard

                    // Selected Day Detail Card
                    if let day = selectedDay {
                        selectedDayCard(day)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("Μηνιαίος Οπωρώνας")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(OrchardColors.appleRed)
                }
            }
        }
    }

    // MARK: - Month Header
    private var monthPickerHeader: some View {
        HStack {
            Button {
                Haptics.selection()
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .padding(8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(OrchardColors.text)

            Spacer()

            Button {
                Haptics.selection()
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .padding(8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
    }

    private func changeMonth(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: selectedMonthDate) {
            selectedMonthDate = newDate
            selectedDay = nil
        }
    }

    // MARK: - Harvest Summary
    private var harvestSummaryCards: some View {
        let fullDays = daysInMonth.filter { $0.status == .fullTarget }.count
        let restDays = daysInMonth.filter { $0.status == .restDay }.count
        let partialDays = daysInMonth.filter { $0.status == .partial }.count

        return HStack(spacing: 10) {
            summaryPill(
                title: "Πλήρη Μήλα",
                count: "\(fullDays)",
                icon: "apple.logo",
                color: OrchardColors.leafGreen
            )

            summaryPill(
                title: "Μερικά",
                count: "\(partialDays)",
                icon: "apple.logo",
                color: OrchardColors.appleRed
            )

            summaryPill(
                title: "Ξεκούραση",
                count: "\(restDays)",
                icon: "leaf.fill",
                color: .orange
            )
        }
    }

    private func summaryPill(title: String, count: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(count)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
            }
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Calendar Grid
    private var calendarGridCard: some View {
        VStack(spacing: 12) {
            // Weekday Headers
            HStack {
                ForEach(weekdayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            Divider()

            // Days Grid
            LazyVGrid(columns: columns, spacing: 10) {
                // Leading padding blanks
                ForEach(0..<leadingPaddingDaysCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: 44)
                }

                // Month days
                ForEach(daysInMonth) { day in
                    dayCell(day)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func dayCell(_ day: OrchardDayModel) -> some View {
        let isSelected = selectedDay?.id == day.id

        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(day.dayNumber)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(day.status == .future ? .secondary.opacity(0.5) : OrchardColors.text)

                switch day.status {
                case .fullTarget:
                    Image(systemName: "apple.logo")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(OrchardColors.leafGreen)
                case .partial:
                    Image(systemName: "apple.logo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OrchardColors.appleRed)
                case .restDay:
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                case .emptyPast:
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                        .frame(width: 14, height: 14)
                case .future:
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? OrchardColors.appleRed.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? OrchardColors.appleRed : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(day.status == .future)
    }

    // MARK: - Selected Day Card
    private func selectedDayCard(_ day: OrchardDayModel) -> some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.dateFormat = "EEEE, d MMMM"
        let dateString = formatter.string(from: day.date).capitalized

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)

                    Text(day.status.title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor(for: day.status))
                }

                Spacer()

                Image(systemName: day.status.iconName)
                    .font(.system(size: 26))
                    .foregroundStyle(statusColor(for: day.status))
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Θερμίδες")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(Int(day.eatenKcal)) / \(Int(day.plannedKcal)) kcal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Γεύματα")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(day.mealCount) καταγεγραμμένα")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    private func statusColor(for status: OrchardDayStatus) -> Color {
        switch status {
        case .fullTarget: return OrchardColors.leafGreen
        case .partial: return OrchardColors.appleRed
        case .restDay: return .orange
        case .emptyPast, .future: return .secondary
        }
    }
}

#Preview {
    OrchardView()
        .environmentObject(AppContainer.shared)
}
