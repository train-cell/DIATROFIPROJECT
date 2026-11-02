import SwiftUI

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Signing Guard")) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(OrchardColors.leafGreen)
                        Text("Active Profile")
                        Spacer()
                        Text("7-day Sideload")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Integrations")) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(OrchardColors.appleRed)
                        Text("Apple Health")
                        Spacer()
                        Text("Ready")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("AI Assistant")) {
                    Toggle("Enable AI Assistant", isOn: .constant(false))
                    Text("The deterministic core functions 100% offline without AI.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0 (M0)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "tab_settings"))
        }
    }
}

#Preview {
    SettingsView()
}
