import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Comprehensive Sleep Architecture & Recovery View inspired by AutoSleep, Bevel, and Apple Sleep.
/// Visualizes deep sleep, REM, core sleep, sleep efficiency, and recovery score from Apple Watch Ultra.
public struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    public let sleepEntry: SleepEntry?

    @State private var subjectiveRating: Int
    @State private var selectedTags: Set<String>
    @State private var animatedProgress: CGFloat = 0.0

    private let availableTags = [
        "Ξεκούραστος", "Βαθύς Ύπνος", "Διακοπές", "Καφεΐνη αργά", "Αργά στο κρεβάτι", "Έντονη Προπόνηση", "Στρες"
    ]

    public init(sleepEntry: SleepEntry?) {
        self.sleepEntry = sleepEntry
        _subjectiveRating = State(initialValue: sleepEntry?.rating ?? 4)
        _selectedTags = State(initialValue: Set(sleepEntry?.tags ?? []))
    }

    private var activeEntry: SleepEntry {
        if var existing = sleepEntry {
            existing.rating = subjectiveRating
            existing.tags = Array(selectedTags)
            return existing
        }
        // Realistic default sample if no Apple Watch entry yet today
        return SleepEntry(
            date: Date(),
            rating: subjectiveRating,
            tags: Array(selectedTags),
            asleepMinutes: 445,       // 7h 25m
            deepSleepMinutes: 85,     // 1h 25m (19%)
            remSleepMinutes: 105,     // 1h 45m (24%)
            coreSleepMinutes: 255,    // 4h 15m (57%)
            awakeMinutes: 30,         // 30m
            inBedMinutes: 475,        // 7h 55m
            hrvMs: 68.0,              // 68 ms (Apple Watch Ultra SDNN)
            restingHeartRateBpm: 52.0 // 52 bpm
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // 1. Recovery & Readiness Hero Gauge (Bevel / Whoop style)
                    recoveryHeroSection

                    // 2. Apple Watch Ultra 3 Sync Badge
                    watchSyncBadge

                    // 3. Biometric Autonomic Nervous System & HRV Section
                    hrvAndRestingHeartRateSection

                    // 4. Sleep Architecture Hypnogram (AutoSleep / Apple Sleep)
                    hypnogramSection

                    // 5. Metric Tiles Grid (Efficiency, Restorative, Debt)
                    metricsGridSection

                    // 6. Subjective Rating & Morning Tags
                    subjectiveRatingSection
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Ανάλυση Ύπνου & Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Τέλος") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(OrchardColors.appleRed)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                    animatedProgress = CGFloat(activeEntry.recoveryScore) / 100.0
                }
            }
            .onChange(of: activeEntry.recoveryScore) { _, newScore in
                withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                    animatedProgress = CGFloat(newScore) / 100.0
                }
            }
        }
    }

    // MARK: - 1. Recovery Hero Section
    private var recoveryHeroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 16)
                    .frame(width: 170, height: 170)

                // Progress Arc (Bevel Gradient)
                Circle()
                    .trim(from: 0.0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Color.cyan, Color.blue, Color.purple],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 170, height: 170)

                // Inner Stats
                VStack(spacing: 4) {
                    Text("\(activeEntry.recoveryScore)%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                        .contentTransition(.numericText())

                    Text("ΑΠΟΚΑΤΑΣΤΑΣΗ")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }
            }
            .padding(.top, 8)

            Text(recoveryHeadline(score: activeEntry.recoveryScore))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(recoveryColor(score: activeEntry.recoveryScore))
                .animation(.easeInOut(duration: 0.3), value: activeEntry.recoveryScore)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 2. Apple Watch Ultra Badge
    private var watchSyncBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .foregroundStyle(Color.cyan)
                .font(.system(size: 14))

            Text("Συγχρονισμός Apple Watch Ultra 3")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary)

            Spacer()

            Text("Live Data")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.cyan.opacity(0.15))
                .foregroundStyle(Color.cyan)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 3. Biometric Autonomic Nervous System & HRV Section
    private var hrvAndRestingHeartRateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Αυτόνομο Νευρικό Σύστημα & HRV", systemImage: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Spacer()

                Text("Apple HealthKit")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // HRV Card
                let hrvVal = Int(round(activeEntry.hrvMs ?? 68.0))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundStyle(Color.green)
                            .font(.system(size: 16))
                        Spacer()
                        Text("SDNN")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text("\(hrvVal) ms")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)

                    Text("HRV Ετοιμότητα")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(activeEntry.hrvStatusDescription)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(hrvVal >= 60 ? Color.green : Color.orange)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.green.opacity(0.18), lineWidth: 1)
                        )
                )

                // Resting Heart Rate Card
                let rhrVal = Int(round(activeEntry.restingHeartRateBpm ?? 52.0))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(OrchardColors.appleRed)
                            .font(.system(size: 16))
                        Spacer()
                        Text("RHR")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text("\(rhrVal) bpm")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)

                    Text("Σφυγμοί Ηρεμίας")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(activeEntry.restingHeartRateStatusDescription)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(rhrVal <= 55 ? Color.cyan : Color.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(OrchardColors.appleRed.opacity(0.18), lineWidth: 1)
                        )
                )
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 4. Hypnogram Section (AutoSleep Stages)
    private var hypnogramSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Στάδια Ύπνου (Hypnogram)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Spacer()

                if let asleep = activeEntry.asleepMinutes {
                    Text(formatHoursMinutes(minutes: asleep))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.blue)
                }
            }

            // Stacked Bar Hypnogram
            let total = max(1.0, Double(activeEntry.inBedMinutes ?? (activeEntry.asleepMinutes ?? 480)))
            let deep = Double(activeEntry.deepSleepMinutes ?? 90)
            let rem = Double(activeEntry.remSleepMinutes ?? 100)
            let core = Double(activeEntry.coreSleepMinutes ?? 250)
            let awake = Double(activeEntry.awakeMinutes ?? 30)

            GeometryReader { geo in
                let spacingTotal: CGFloat = 3 * 3 // 3 spaces of 3pt
                let availableWidth = max(0, geo.size.width - spacingTotal)
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.35, green: 0.30, blue: 0.85)) // Deep Purple
                        .frame(width: max(8, availableWidth * CGFloat(deep / total)))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cyan) // REM Cyan
                        .frame(width: max(8, availableWidth * CGFloat(rem / total)))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue) // Core Blue
                        .frame(width: max(8, availableWidth * CGFloat(core / total)))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.85)) // Awake Amber
                        .frame(width: max(8, availableWidth * CGFloat(awake / total)))
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Stage Legend
            HStack(spacing: 12) {
                stageLegendItem(name: "Βαθύς", minutes: Int(deep), color: Color(red: 0.35, green: 0.30, blue: 0.85))
                stageLegendItem(name: "REM", minutes: Int(rem), color: Color.cyan)
                stageLegendItem(name: "Ελαφρύς", minutes: Int(core), color: Color.blue)
                stageLegendItem(name: "Αφύπνιση", minutes: Int(awake), color: Color.orange)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func stageLegendItem(name: String, minutes: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(formatHoursMinutes(minutes: minutes))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 4. Metrics Grid Section
    private var metricsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            metricCard(
                title: "Αποδοτικότητα",
                value: "\(Int(activeEntry.efficiencyPercentage ?? 92))%",
                subtitle: "Χρόνος στο κρεβάτι: \(formatHoursMinutes(minutes: activeEntry.inBedMinutes ?? 475))",
                icon: "gauge.with.needle.fill",
                color: Color.green
            )

            metricCard(
                title: "Επανορθωτικός",
                value: "\(Int(activeEntry.restorativePercentage ?? 42))%",
                subtitle: "Στόχος: 35-45% (Deep + REM)",
                icon: "bolt.heart.fill",
                color: Color.purple
            )

            metricCard(
                title: "Χρέος Ύπνου",
                value: formatDebt(minutes: activeEntry.sleepDebtMinutes ?? -15),
                subtitle: "Βάση: 8 ώρες ανάπαυσης",
                icon: "hourglass.badge.plus",
                color: (activeEntry.sleepDebtMinutes ?? 0) >= 0 ? Color.green : Color.orange
            )

            metricCard(
                title: "Υποκειμενική Αίσθηση",
                value: "\(subjectiveRating) / 5",
                subtitle: "Πρωινή αξιολόγηση",
                icon: "star.fill",
                color: Color.yellow
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
                Spacer()
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(OrchardColors.text)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 5. Subjective Rating Section
    private var subjectiveRatingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Πώς νιώθεις σήμερα το πρωί;")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(OrchardColors.text)

            // Star Rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.selection()
                        subjectiveRating = star
                    } label: {
                        Image(systemName: star <= subjectiveRating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(star <= subjectiveRating ? Color.yellow : Color.secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            // Tags Chips
            Text("Παράγοντες:")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(availableTags, id: \.self) { tag in
                    let isSelected = selectedTags.contains(tag)
                    Button {
                        Haptics.selection()
                        if isSelected {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? OrchardColors.leafGreen : Color.secondary.opacity(0.12))
                            .foregroundStyle(isSelected ? Color.white : OrchardColors.text)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helper Formatting
    private func formatHoursMinutes(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)ώ \(m)λ"
        }
        return "\(m)λ"
    }

    private func formatDebt(minutes: Int) -> String {
        if minutes >= 0 {
            return "+\(formatHoursMinutes(minutes: minutes))"
        }
        return "-\(formatHoursMinutes(minutes: abs(minutes)))"
    }

    private func recoveryHeadline(score: Int) -> String {
        if score >= 80 {
            return "Εξαιρετική Αποκατάσταση — Έτοιμος για υψηλή ένταση!"
        } else if score >= 60 {
            return "Ικανοποιητική Ανάκαμψη — Κανονική προπόνηση"
        } else {
            return "Χαμηλή Ετοιμότητα — Συνιστάται ελαφριά άσκηση ή ξεκούραση"
        }
    }

    private func recoveryColor(score: Int) -> Color {
        if score >= 80 {
            return Color.green
        } else if score >= 60 {
            return Color.cyan
        } else {
            return Color.orange
        }
    }
}

/// Simple flow layout helper for tags chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
