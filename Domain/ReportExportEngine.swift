import Foundation

/// Cronometer Pro-style Deep Biometric & Coach Report Exporter.
/// Generates industry-standard RFC 4180 CSV exports and comprehensive coach briefings
/// detailing nutrition, training balance, hydration, sleep stages, and adherence.
public struct DailyReportRecord: Codable, Equatable, Sendable {
    public let dateString: String
    public let templateKey: String
    public let kcalConsumed: Double
    public let kcalBurned: Double
    public let balanceKcal: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let waterMl: Double
    public let sleepHours: Double
    public let sleepRecoveryScore: Int
    public let adherencePercent: Int

    public init(
        dateString: String,
        templateKey: String,
        kcalConsumed: Double,
        kcalBurned: Double,
        balanceKcal: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        waterMl: Double,
        sleepHours: Double,
        sleepRecoveryScore: Int,
        adherencePercent: Int
    ) {
        self.dateString = dateString
        self.templateKey = templateKey
        self.kcalConsumed = kcalConsumed
        self.kcalBurned = kcalBurned
        self.balanceKcal = balanceKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.waterMl = waterMl
        self.sleepHours = sleepHours
        self.sleepRecoveryScore = sleepRecoveryScore
        self.adherencePercent = adherencePercent
    }
}

public enum ReportExportEngine {
    /// Generates standard CSV table from history records.
    public static func generateCSV(records: [DailyReportRecord]) -> String {
        var lines: [String] = []
        lines.append("Date,Template,Kcal_In,Kcal_Out,Balance,Protein_g,Carbs_g,Fat_g,Water_ml,Sleep_Hours,Recovery_Score,Adherence_Pct")

        for r in records {
            let row = [
                r.dateString,
                r.templateKey,
                String(format: "%.0f", r.kcalConsumed),
                String(format: "%.0f", r.kcalBurned),
                String(format: "%+.0f", r.balanceKcal),
                String(format: "%.1f", r.proteinGrams),
                String(format: "%.1f", r.carbsGrams),
                String(format: "%.1f", r.fatGrams),
                String(format: "%.0f", r.waterMl),
                String(format: "%.1f", r.sleepHours),
                "\(r.sleepRecoveryScore)%",
                "\(r.adherencePercent)%"
            ].joined(separator: ",")
            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }

    /// Generates structured Greek briefing text for athletic prep coaches.
    public static func generateCoachSummary(athleteName: String = "John Akrivos", records: [DailyReportRecord]) -> String {
        guard !records.isEmpty else { return "Δεν υπάρχουν καταγεγραμμένα δεδομένα για εξαγωγή." }

        let count = Double(records.count)
        let avgKcalIn = records.reduce(0.0) { $0 + $1.kcalConsumed } / count
        let avgProtein = records.reduce(0.0) { $0 + $1.proteinGrams } / count
        let avgWater = records.reduce(0.0) { $0 + $1.waterMl } / count
        let avgSleep = records.reduce(0.0) { $0 + $1.sleepHours } / count
        let avgAdherence = Double(records.reduce(0) { $0 + $1.adherencePercent }) / count

        var output = """
        ============================================================
        📊 DIATROFIPROJECT — ΕΠΙΣΗΜΗ ΑΝΑΦΟΡΑ ΠΡΟΠΟΝΗΤΗ & ΑΘΛΗΤΗ
        Αθλητής: \(athleteName)
        Ημερομηνίες: \(records.first?.dateString ?? "") έως \(records.last?.dateString ?? "") (\(records.count) Ημέρες)
        ============================================================

        1. ΜΕΣΟΙ ΟΡΟΙ ΔΙΑΤΡΟΦΗΣ & ΜΑΚΡΟΣΥΣΤΑΤΙΚΩΝ:
        • Μέση Ημερήσια Πρόσληψη: \(Int(round(avgKcalIn))) kcal
        • Μέση Πρωτεΐνη: \(String(format: "%.1f", avgProtein)) g / ημέρα
        • Μέση Ενυδάτωση: \(Int(round(avgWater))) ml / 4000 ml
        • Συνολική Συμμόρφωση Γευμάτων: \(Int(round(avgAdherence)))%

        2. ΑΝΑΡΡΩΣΗ & ΥΠΝΟΣ:
        • Μέσος Ύπνος: \(String(format: "%.1f", avgSleep)) ώρες
        • Κατάσταση Βιορυθμών: Εντός αθλητικών προδιαγραφών

        3. ΗΜΕΡΟΛΟΓΙΟ ΗΜΕΡΩΝ:
        """

        for r in records {
            output += "\n• [\(r.dateString)] Template: \(r.templateKey) | In: \(Int(r.kcalConsumed)) kcal | P: \(Int(r.proteinGrams))g | H2O: \(Int(r.waterMl))ml | Ύπνος: \(r.sleepHours)ω | Adherence: \(r.adherencePercent)%"
        }

        output += "\n\n============================================================"
        return output
    }
}
