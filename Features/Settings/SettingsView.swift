import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif
#if canImport(OrchardServices)
import OrchardServices
#endif
#if canImport(HealthKit)
import HealthKit
#endif

/// Comprehensive Application Settings screen featuring 7-day signing guard status,
/// real Apple HealthKit connection, privacy-first local telemetry, and AI Assistant settings.
public struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer

    // Signing Guard
    private let signingGuard = SigningGuard()
    @State private var showSigningHelpSheet: Bool = false

    // HealthKit Status
    @State private var healthStatusMessage: String = "Έτοιμο για σύνδεση"
    @State private var isRequestingHealth: Bool = false

    // Telemetry
    @AppStorage("orchard_telemetry_enabled") private var telemetryEnabled: Bool = true
    @State private var telemetryEventCount: Int = 0
    @State private var showLogsSheet: Bool = false
    @State private var recentLogs: [TelemetryEvent] = []
    @State private var exportedLogURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var showClearConfirmAlert: Bool = false

    // AI Assistant
    @AppStorage("orchard_ai_enabled") private var aiEnabled: Bool = true
    @AppStorage("orchard_ai_provider") private var selectedAIProvider: String = "on_device"
    @AppStorage("orchard_ai_api_key") private var apiKey: String = ""
    @State private var showApiKeySavedToast: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // 1. 7-Day Signing Expiry Banner Section
                signingGuardSection

                // 2. Real Apple Health Section
                appleHealthSection

                // 3. Local Privacy-First Telemetry Section
                telemetrySection

                // 4. AI Assistant Section
                aiAssistantSection

                // 5. About & Architecture Section
                aboutSection
            }
            .navigationTitle(String(localized: "tab_settings"))
            .sheet(isPresented: $showSigningHelpSheet) {
                signingHelpSheet
            }
            .sheet(isPresented: $showLogsSheet) {
                telemetryLogsSheet
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedLogURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Εκκαθάριση Τοπικών Logs;", isPresented: $showClearConfirmAlert) {
                Button("Ακύρωση", role: .cancel) {}
                Button("Εκκαθάριση", role: .destructive) {
                    clearTelemetryLogs()
                }
            } message: {
                Text("Όλα τα τοπικά διαγνωστικά συμβάντα θα διαγραφούν οριστικά από τη συσκευή.")
            }
            .task {
                await loadTelemetryStats()
            }
        }
    }

    // MARK: - 1. 7-Day Signing Expiry Banner
    private var signingGuardSection: some View {
        Section(header: Text("ΠΙΣΤΟΠΟΙΗΤΙΚΟ ΕΓΚΑΤΑΣΤΑΣΗΣ (7-DAY SIDELOAD)")) {
            let hours = signingGuard.hoursRemaining
            let days = signingGuard.daysRemaining

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(signingBannerColor(hours: hours).opacity(0.18))
                            .frame(width: 40, height: 40)

                        Image(systemName: signingBannerIcon(hours: hours))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(signingBannerColor(hours: hours))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(signingBannerTitle(hours: hours, days: days))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)

                        Text(signingBannerSubtitle(hours: hours))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()

                Button {
                    Haptics.selection()
                    showSigningHelpSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text("Πώς να ανανεώσετε μέσω Xcode")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(OrchardColors.appleRed)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    private func signingBannerColor(hours: Int) -> Color {
        if hours > 48 {
            return OrchardColors.leafGreen
        } else if hours > 2 {
            return Color.orange
        } else {
            return OrchardColors.appleRed
        }
    }

    private func signingBannerIcon(hours: Int) -> String {
        if hours > 48 {
            return "checkmark.shield.fill"
        } else if hours > 2 {
            return "exclamationmark.shield.fill"
        } else {
            return "xmark.shield.fill"
        }
    }

    private func signingBannerTitle(hours: Int, days: Int) -> String {
        if hours > 48 {
            return "Ενεργό Προφίλ: \(days) ημέρες απομένουν"
        } else if hours > 2 {
            return "Προσοχή: Λήγει σε \(hours) ώρες"
        } else {
            return "Κρίσιμο: Λήγει άμεσα (< 2 ώρες)!"
        }
    }

    private func signingBannerSubtitle(hours: Int) -> String {
        if hours > 48 {
            return "Το προφίλ σας λειτουργεί κανονικά."
        } else if hours > 2 {
            return "Συνδέστε τη συσκευή στο Mac για ανανέωση."
        } else {
            return "Απαιτείται άμεση επανασύνδεση στο Xcode."
        }
    }

    private var signingHelpSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 32))
                        .foregroundStyle(OrchardColors.appleRed)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ανανέωση 7 Ημερών (Apple ID)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.text)
                        Text("Προσωπικό Πιστοποιητικό Sideloading")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 10)

                Divider()

                VStack(alignment: .leading, spacing: 14) {
                    helpStepRow(number: "1", title: "Σύνδεση", text: "Συνδέστε το iPhone στο Mac σας με καλώδιο USB-C ή μέσω τοπικού Wi-Fi.")
                    helpStepRow(number: "2", title: "Xcode", text: "Ανοίξτε το Orchard.xcodeproj στο Xcode.")
                    helpStepRow(number: "3", title: "Εκτέλεση (Run)", text: "Επιλέξτε το iPhone σας ως προορισμό και πατήστε το πλήκτρο Run (Cmd + R).")
                    helpStepRow(number: "4", title: "Ολοκλήρωση", text: "Το πιστοποιητικό ανανεώνεται αυτόματα για άλλες 7 ημέρες χωρίς καμία απώλεια στα δεδομένα σας.")
                }

                Spacer()

                Button("Το κατάλαβα") {
                    showSigningHelpSheet = false
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(OrchardColors.appleRed)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(20)
            .navigationTitle("Οδηγίες Xcode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func helpStepRow(number: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(width: 26, height: 26)
                .background(OrchardColors.appleRed.opacity(0.12))
                .foregroundStyle(OrchardColors.appleRed)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
                Text(text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 2. Real Apple Health Section
    private var appleHealthSection: some View {
        Section(header: Text("APPLE HEALTH (HEALTHKIT)")) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(OrchardColors.appleRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Συγχρονισμός Υγείας")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(OrchardColors.text)

                    Text(healthStatusMessage)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    requestHealthKitAuth()
                } label: {
                    if isRequestingHealth {
                        ProgressView()
                    } else {
                        Text("Σύνδεση")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(OrchardColors.appleRed.opacity(0.12))
                            .foregroundStyle(OrchardColors.appleRed)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }

            Text("Συγχρονίζει αυτόματα προπονήσεις, ενεργές θερμίδες και καταγραφές διατροφής με το Apple Health.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func requestHealthKitAuth() {
        Haptics.selection()
        isRequestingHealth = true
        Task {
            do {
                let success = try await container.healthStore.requestAuthorization()
                await MainActor.run {
                    isRequestingHealth = false
                    if success {
                        healthStatusMessage = "Συνδεδεμένο & Ενεργό ✅"
                        Haptics.success()
                    } else {
                        healthStatusMessage = "Μη εξουσιοδοτημένο"
                        Haptics.warning()
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingHealth = false
                    healthStatusMessage = "Σφάλμα σύνδεσης"
                    Haptics.error()
                }
            }
        }
    }

    // MARK: - 3. Local Privacy-First Telemetry Section
    private var telemetrySection: some View {
        Section(header: Text("ΤΟΠΙΚΟ ΑΡΧΕΙΟ ΤΗΛΕΜΕΤΡΙΑΣ (PRIVACY-FIRST)")) {
            Toggle("Ενεργοποίηση Τοπικών Logs", isOn: $telemetryEnabled)
                .font(.system(size: 15, weight: .medium, design: .rounded))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(telemetryEventCount) τοπικά συμβάντα καταγεγραμμένα")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("100% ιδιωτικότητα. Κανένα δεδομένο δεν αποστέλλεται σε εξωτερικούς διακομιστές. Αποθηκεύονται μόνο τοπικά στη συσκευή.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            HStack(spacing: 12) {
                Button {
                    Haptics.selection()
                    Task {
                        recentLogs = await TelemetryService.shared.getRecentEvents(limit: 50)
                        showLogsSheet = true
                    }
                } label: {
                    Text("Προβολή Logs")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }

                Spacer()

                Button {
                    Haptics.selection()
                    Task {
                        if let url = await TelemetryService.shared.exportLogs() {
                            exportedLogURL = url
                            showShareSheet = true
                        }
                    }
                } label: {
                    Text("Εξαγωγή JSONL")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }

                Spacer()

                Button(role: .destructive) {
                    Haptics.selection()
                    showClearConfirmAlert = true
                } label: {
                    Text("Καθαρισμός")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func loadTelemetryStats() async {
        let events = await TelemetryService.shared.getRecentEvents(limit: 1000)
        await MainActor.run {
            self.telemetryEventCount = events.count
        }
    }

    private func clearTelemetryLogs() {
        Task {
            await TelemetryService.shared.clearLogs()
            await loadTelemetryStats()
            Haptics.success()
        }
    }

    private var telemetryLogsSheet: some View {
        NavigationStack {
            List {
                if recentLogs.isEmpty {
                    Text("Δεν υπάρχουν καταγεγραμμένα συμβάντα.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentLogs.indices, id: \.self) { idx in
                        let event = recentLogs[idx]
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(event.type)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(OrchardColors.text)
                                Spacer()
                                Text(event.timestamp, style: .time)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            if let params = event.parameters, !params.isEmpty {
                                Text(params.description)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Τοπικά Logs JSONL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Κλείσιμο") {
                        showLogsSheet = false
                    }
                }
            }
        }
    }

    // MARK: - 4. AI Assistant Section
    private var aiAssistantSection: some View {
        Section(header: Text("AI ΒΟΗΘΟΣ ΔΙΑΤΡΟΦΗΣ")) {
            Toggle("Ενεργοποίηση AI Βοηθού", isOn: $aiEnabled)
                .font(.system(size: 15, weight: .medium, design: .rounded))

            if aiEnabled {
                Picker("Πάροχος AI", selection: $selectedAIProvider) {
                    Text("On-Device (Apple Intelligence)").tag("on_device")
                    Text("Cloud (OpenAI / Anthropic)").tag("cloud")
                    Text("Offline / Mock").tag("offline")
                }

                if selectedAIProvider == "cloud" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key:")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        SecureField("sk-...", text: $apiKey)
                            .font(.system(size: 14, design: .monospaced))
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Haptics.success()
                            showApiKeySavedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showApiKeySavedToast = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                Text(showApiKeySavedToast ? "Αποθηκεύτηκε στο Keychain! ✅" : "Αποθήκευση στο Keychain 🔒")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(showApiKeySavedToast ? OrchardColors.leafGreen : OrchardColors.appleRed)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Text("Ο ντετερμινιστικός πυρήνας της εφαρμογής λειτουργεί 100% offline χωρίς καμία απαίτηση AI.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 5. About Section
    private var aboutSection: some View {
        Section(header: Text("ΣΧΕΤΙΚΑ ΜΕ ΤΟ ORCHARD")) {
            HStack {
                Text("Έκδοση")
                Spacer()
                Text("0.3.0 (M3/M4/M5/M6)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Αρχιτεκτονική")
                Spacer()
                Text("Pure Swift Domain Core")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Ασφάλεια & Ιδιωτικότητα")
                Spacer()
                Text("100% On-Device")
                    .foregroundStyle(OrchardColors.leafGreen)
            }
        }
    }
}

/// Helper UIKit Activity Share Sheet for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(AppContainer.shared)
}
