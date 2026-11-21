import Foundation

/// Pure deterministic context and system prompt engine for the AI Nutrition Coach.
public enum NutritionContextBuilder {

    /// Constructs a complete, highly structured system prompt in Greek embedding the entire
    /// nutrition protocol and the athlete's real-time daily progress.
    public static func buildSystemPrompt(
        plan: Plan,
        snapshot: AICoachDailySnapshot,
        timeZone: TimeZone = .current
    ) -> String {
        var lines: [String] = []

        // 1. Role & Athlete Persona
        lines.append("Είσαι ο Antigravity AI Nutrition Coach για την εφαρμογή Orchard.")
        lines.append("Καθοδηγείς έναν αθλητή υψηλού επιπέδου (\(plan.settings.sport ?? "Τεχνική Κολύμβηση")) με βάση το εξατομικευμένο διατροφικό πρωτόκολλο της κλινικής διατροφολόγου.")
        if let label = plan.settings.planLabel {
            lines.append("Ενεργό Πρόγραμμα: \(label)")
        }
        lines.append("")

        // 2. Settings & Daily Schedule
        lines.append("=== ΒΑΣΙΚΕΣ ΡΥΘΜΙΣΕΙΣ & ΩΡΑΡΙΟ ===")
        lines.append("- Ώρα αφύπνισης: \(plan.settings.wake)")
        lines.append("- Ώρα ύπνου: \(plan.settings.bed)")
        lines.append("- Ελάχιστο κενό μεταξύ γευμάτων: \(plan.settings.minMealGapMinutes) λεπτά")
        lines.append("- Ημερήσιος στόχος νερού: \(Int(plan.settings.targetWaterMl)) ml")
        if let minW = plan.settings.minWaterMl {
            lines.append("- Ελάχιστη ενυδάτωση: \(Int(minW)) ml")
        }
        lines.append("")

        // 3. Current Day Status
        let weekdayGreek: String = {
            switch snapshot.weekday {
            case .mon: return "Δευτέρα (Monday)"
            case .tue: return "Τρίτη (Tuesday)"
            case .wed: return "Τετάρτη (Wednesday)"
            case .thu: return "Πέμπτη (Thursday)"
            case .fri: return "Παρασκευή (Friday)"
            case .sat: return "Σάββατο (Saturday)"
            case .sun: return "Κυριακή (Sunday)"
            }
        }()

        lines.append("=== ΣΗΜΕΡΙΝΗ ΚΑΤΑΣΤΑΣΗ ===")
        lines.append("- Ημέρα: \(weekdayGreek)")
        lines.append("- Επιλεγμένο Mode Ημέρας: \(snapshot.selectedTemplateKey)")
        lines.append("- Ενυδάτωση σήμερα: \(Int(snapshot.waterIntakeMl)) ml / \(Int(snapshot.targetWaterMl)) ml στόχος")

        let isFerroDay = (snapshot.weekday == .wed || snapshot.weekday == .fri)
        if isFerroDay {
            lines.append("- ΣΗΜΕΡΑ ΕΙΝΑΙ ΗΜΕΡΑ ΣΙΔΗΡΟΥ (Τετάρτη/Παρασκευή): Λαμβάνεται 1 FERRO SANOL DUODENAL 100mg μαζί με Βιταμίνη C 500 αναβράζουσα.")
        } else {
            lines.append("- ΣΗΜΕΡΑ ΔΕΝ ΕΙΝΑΙ ΗΜΕΡΑ ΣΙΔΗΡΟΥ: Το FERRO SANOL λαμβάνεται ΑΥΣΤΗΡΑ ΜΟΝΟ Τετάρτη και Παρασκευή (όχι σήμερα).")
        }
        lines.append("")

        // 4. Logged vs Remaining Events
        if !snapshot.logEntries.isEmpty {
            lines.append("--- Καταγεγραμμένα Σήμερα ---")
            for entry in snapshot.logEntries where entry.status == .done {
                let note = entry.note ?? entry.selectedOptionTitle ?? "Ολοκληρώθηκε"
                let cals = entry.kcal != nil ? "\(Int(entry.kcal!)) kcal" : ""
                lines.append("• [\(entry.itemId)] \(note) \(cals)")
            }
            lines.append("")
        }

        if !snapshot.resolvedEvents.isEmpty {
            lines.append("--- Πρόγραμμα Σημερινής Ημέρας (Timeline) ---")
            for event in snapshot.resolvedEvents {
                let isLogged = snapshot.logEntries.contains { ($0.itemId == event.itemId || $0.eventKey == event.id) && $0.status == .done }
                let statusMark = isLogged ? "✅ [ΚΑΤΑΓΕΓΡΑΜΜΕΝΟ]" : "⏳ [ΕΚΚΡΕΜΕΙ]"
                let timeStr = formatTime(event.resolvedTime, timeZone: timeZone)
                let item = event.item
                var details = "\(statusMark) \(timeStr) - [\(item.id)] \(item.title)"
                if let w = item.waterMl, w > 0 {
                    details += " (💧 \(Int(w))ml)"
                }
                if let k = item.kcal, k > 0 {
                    details += " (\(Int(k)) kcal, P:\(Int(item.protein ?? 0))g, C:\(Int(item.carbs ?? 0))g, F:\(Int(item.fat ?? 0))g)"
                }
                lines.append(details)
            }
            lines.append("")
        }

        // 5. Full Plan Catalog (All 5 Templates & Modular Options)
        lines.append("=== ΠΛΗΡΕΣ ΚΑΤΑΛΟΓΟΣ ΠΡΟΓΡΑΜΜΑΤΟΣ (5 MODES & MODULAR OPTIONS) ===")
        for (key, template) in plan.templates.sorted(by: { ($0.value.order ?? 0) < ($1.value.order ?? 0) }) {
            let tTitle = template.title ?? key
            lines.append("MODE: [\(key)] - \(tTitle)")
            for item in template.items {
                var itemLine = "  • Item [\(item.id)] \"\(item.title)\" (τύπος: \(item.type.rawValue))"
                if let activeW = item.activeWeekdays, !activeW.isEmpty {
                    itemLine += " [Ενεργό μόνο: \(activeW.map(\.rawValue).joined(separator: ", "))]"
                }
                if let w = item.waterMl { itemLine += " (💧 \(Int(w))ml)" }
                if let k = item.kcal { itemLine += " (\(Int(k)) kcal, P:\(Int(item.protein ?? 0))g, C:\(Int(item.carbs ?? 0))g, F:\(Int(item.fat ?? 0))g)" }
                if let notes = item.notes { itemLine += " - Οδηγίες: \(notes)" }
                lines.append(itemLine)

                if let options = item.options, !options.isEmpty {
                    for opt in options {
                        var optLine = "      - Option [\(opt.id)] \"\(opt.title)\""
                        if let d = opt.details { optLine += ": \(d)" }
                        if let k = opt.kcal { optLine += " (\(Int(k)) kcal, P:\(Int(opt.protein ?? 0))g, C:\(Int(opt.carbs ?? 0))g, F:\(Int(opt.fat ?? 0))g)" }
                        lines.append(optLine)
                    }
                }
            }
            lines.append("")
        }

        // 6. Strict Output Schema Contract
        lines.append("=== ΑΥΣΤΗΡΟ ΣΥΜΒΟΛΑΙΟ ΕΞΟΔΟΥ JSON (ZERO HALLUCINATION) ===")
        lines.append("Απαντάς ΠΑΝΤΑ και ΑΥΣΤΗΡΑ σε έγκυρη μορφή JSON (χωρίς markdown backticks ή άλλο κείμενο):")
        lines.append("""
        {
          "replyGreek": "Σύντομη, φιλική και αθλητικά τεκμηριωμένη απάντηση στα Ελληνικά.",
          "suggestedActions": [
            {
              "id": "act_1",
              "kind": "meal" | "supplement" | "water",
              "itemId": "itemId_από_τον_κατάλογο_αν_ταιριάζει_αλλιώς_null",
              "selectedOptionId": "optionId_από_τον_κατάλογο_αν_ταιριάζει_αλλιώς_null",
              "title": "Τίτλος ενέργειας",
              "kcal": 350.0,
              "protein": 25.0,
              "carbs": 30.0,
              "fat": 10.0,
              "waterMl": 500.0,
              "notes": "Σημειώσεις"
            }
          ]
        }
        """)
        lines.append("ΚΑΝΟΝΕΣ:")
        lines.append("1. Όταν ο αθλητής αναφέρει ότι έφαγε ή πήρε κάτι από το πρόγραμμα, βάλε στο suggestedActions το ακριβές itemId και selectedOptionId.")
        lines.append("2. Για υγρά συμπληρώματα (HIGH5+BCAA, νερό), βάλε το κατάλληλο waterMl (π.χ. 500.0).")
        lines.append("3. Αν ο χρήστης ρωτάει απλώς πληροφορία ή συμβουλή (χωρίς να καταγράφει γεύμα), το suggestedActions είναι κενό [].")
        lines.append("4. Μηδενική ψευδαίσθηση (Zero Hallucination): Ποτέ μην εφευρίσκεις συμπληρώματα εκτός πρωτοκόλλου. FERRO SANOL αυστηρά μόνο Τετάρτη και Παρασκευή.")

        return lines.joined(separator: "\n")
    }

    private static func formatTime(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
