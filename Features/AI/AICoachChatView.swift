import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif
#if canImport(OrchardServices)
import OrchardServices
#endif

/// Premium Native SwiftUI Chat Sheet for the AI Nutrition Coach (Gemini BYOK).
public struct AICoachChatView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private let starterPrompts: [String] = [
        "Τι να φάω τώρα πριν την προπόνηση;",
        "Έφαγα το ταπεράκι με σολομό",
        "Πήρα το 2ο 500άρι με AFTER και γλουταμίνη",
        "Τι συμπληρώματα απομένουν σήμερα;",
        "Πώς φτιάχνω την ομελέτα βρώμης;"
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Status & Controls Subheader
                subheaderSection

                Divider()

                // 2. Error Banner (if any)
                if let err = errorMessage {
                    errorBanner(err)
                }

                // 3. Messages Feed / Starter Prompts
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if container.aiChatMessages.isEmpty {
                                starterPromptsSection
                            } else {
                                ForEach(container.aiChatMessages) { msg in
                                    messageRow(msg: msg)
                                        .id(msg.id)
                                }
                            }

                            if isLoading {
                                loadingBubble
                                    .id("loading_bubble")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: container.aiChatMessages.count) { _, _ in
                        withAnimation {
                            if let lastId = container.aiChatMessages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation {
                                proxy.scrollTo("loading_bubble", anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // 4. Bottom Input Bar
                inputBarSection
            }
            .background(OrchardColors.background.ignoresSafeArea())
            .navigationTitle("AI Nutrition Coach ✨")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Κλείσιμο") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !container.aiChatMessages.isEmpty {
                        Button {
                            Haptics.selection()
                            container.clearAIChat()
                            errorMessage = nil
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 1. Subheader Section (Status Badge & Auto-Log Toggle)
    private var subheaderSection: some View {
        let hasKey: Bool = {
            let key = KeychainStore.shared.getAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
            return key != nil && !key!.isEmpty
        }()

        return VStack(spacing: 8) {
            HStack {
                // BYOK Status Pill
                HStack(spacing: 5) {
                    Image(systemName: hasKey ? "sparkles" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(hasKey ? "Gemini BYOK • 12 Models" : "Λείπει API Key")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(hasKey ? Color.purple.opacity(0.12) : Color.orange.opacity(0.15))
                .foregroundStyle(hasKey ? Color.purple : Color.orange)
                .clipShape(Capsule())

                Spacer()

                // Auto-Log Toggle
                Toggle(isOn: $container.aiAutoLogEnabled) {
                    HStack(spacing: 4) {
                        Text("Auto-Log")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(container.aiAutoLogEnabled ? OrchardColors.leafGreen : .secondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: OrchardColors.leafGreen))
                .scaleEffect(0.8)
            }

            if !hasKey {
                Text("Βάλε το δωρεάν Gemini API Key σου στις Ρυθμίσεις → AI Βοηθός για ζωντανή ανάλυση.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - 2. Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(OrchardColors.appleRed)
                .font(.system(size: 14))

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(OrchardColors.appleRed)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(OrchardColors.appleRed.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 3. Starter Prompts Section
    private var starterPromptsSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.purple)
            }

            VStack(spacing: 4) {
                Text("Πώς μπορώ να σε βοηθήσω σήμερα;")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)

                Text("Ρώτησε για το πλάνο σου ή πες μου τι έφαγες / ήπιες για άμεση καταγραφή.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                ForEach(starterPrompts, id: \.self) { prompt in
                    Button {
                        Haptics.selection()
                        sendPrompt(prompt)
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.purple)
                            Text(prompt)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(OrchardColors.text)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 4. Message Bubble & Suggested Actions
    private func messageRow(msg: AICoachChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.isUser {
                Spacer(minLength: 44)
                Text(msg.text)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.purple)
                    .frame(width: 28, height: 28)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(Circle())
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text(msg.text)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(OrchardColors.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Suggested Actions Card
                    if !msg.suggestedActions.isEmpty {
                        suggestedActionsCard(msg: msg)
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }

    private func suggestedActionsCard(msg: AICoachChatMessage) -> some View {
        let actions = msg.suggestedActions
        let unapplied = actions.filter { !msg.appliedActionIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .bold))
                    Text("ΠΡΟΤΕΙΝΟΜΕΝΕΣ ΚΑΤΑΓΡΑΦΕΣ")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                }
                .foregroundStyle(Color.purple)

                Spacer()

                if unapplied.count > 1 {
                    Button {
                        Haptics.success()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            for act in unapplied {
                                let logId = container.applyAICoachAction(act)
                                if let idx = container.aiChatMessages.firstIndex(where: { $0.id == msg.id }) {
                                    container.aiChatMessages[idx].appliedActionIds.insert(act.id)
                                    if let logId {
                                        container.aiChatMessages[idx].appliedLogIds[act.id] = logId
                                    }
                                }
                            }
                        }
                    } label: {
                        Text("Καταγραφή Όλων ✅")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(OrchardColors.leafGreen.opacity(0.15))
                            .foregroundStyle(OrchardColors.leafGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 8) {
                ForEach(actions) { action in
                    let isApplied = msg.appliedActionIds.contains(action.id)
                    actionItemRow(action: action, isApplied: isApplied, msg: msg)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private func actionItemRow(action: AICoachLogAction, isApplied: Bool, msg: AICoachChatMessage) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Action Icon
            Image(systemName: actionIconName(for: action.kind))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(actionIconColor(for: action.kind))
                .frame(width: 26, height: 26)
                .background(actionIconColor(for: action.kind).opacity(0.12))
                .clipShape(Circle())

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrchardColors.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let k = action.kcal, k > 0 {
                        Text("\(Int(k)) kcal")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(OrchardColors.appleRed)
                    }
                    if let p = action.protein, p > 0 {
                        Text("• \(Int(p))g P")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let c = action.carbs, c > 0 {
                        Text("• \(Int(c))g C")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let f = action.fat, f > 0 {
                        Text("• \(Int(f))g F")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let water = action.waterMl, water > 0 {
                        Text("+\(Int(water))ml")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cyan)
                    }
                }
            }

            Spacer()

            // Confirm / Undo Button
            if isApplied {
                HStack(spacing: 4) {
                    Text("Καταγράφηκε ✅")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(OrchardColors.leafGreen)

                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            let logId = msg.appliedLogIds[action.id]
                            container.undoAICoachAction(action, appliedLogId: logId)
                            if let idx = container.aiChatMessages.firstIndex(where: { $0.id == msg.id }) {
                                container.aiChatMessages[idx].appliedActionIds.remove(action.id)
                                container.aiChatMessages[idx].appliedLogIds.removeValue(forKey: action.id)
                            }
                        }
                    } label: {
                        Text("Αναίρεση")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    Haptics.success()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        let logId = container.applyAICoachAction(action)
                        if let idx = container.aiChatMessages.firstIndex(where: { $0.id == msg.id }) {
                            container.aiChatMessages[idx].appliedActionIds.insert(action.id)
                            if let logId {
                                container.aiChatMessages[idx].appliedLogIds[action.id] = logId
                            }
                        }
                    }
                } label: {
                    Text("Καταγραφή ✅")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(Color.purple)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private var loadingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.purple)
                .frame(width: 28, height: 28)
                .background(Color.purple.opacity(0.12))
                .clipShape(Circle())

            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Ο AI Coach επεξεργάζεται το πλάνο σου...")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
        }
    }

    // MARK: - 5. Bottom Input Bar Section
    private var inputBarSection: some View {
        HStack(spacing: 10) {
            TextField("Ρώτησε ή πες τι έφαγες...", text: $inputText, axis: .vertical)
                .font(.system(size: 14, design: .rounded))
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(isLoading)

            Button {
                let text = inputText
                inputText = ""
                sendPrompt(text)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                            ? Color.secondary.opacity(0.4)
                            : Color.purple
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Private Action Helpers

    private func sendPrompt(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await container.sendAICoachMessage(trimmed)
                await MainActor.run {
                    self.isLoading = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    Haptics.warning()
                }
            }
        }
    }

    private func actionIconName(for kind: AICoachActionKind) -> String {
        switch kind {
        case .meal: return "fork.knife"
        case .supplement: return "pill.fill"
        case .water: return "drop.fill"
        }
    }

    private func actionIconColor(for kind: AICoachActionKind) -> Color {
        switch kind {
        case .meal: return OrchardColors.appleRed
        case .supplement: return Color.indigo
        case .water: return Color.cyan
        }
    }
}
