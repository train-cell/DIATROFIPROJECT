import SwiftUI

public struct LogView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 48))
                    .foregroundStyle(OrchardColors.appleRed)

                Text("Quick Log")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(OrchardColors.text)

                Text("Log meals, supplements, and snacks quickly.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OrchardColors.background)
            .navigationTitle(String(localized: "tab_log"))
        }
    }
}

#Preview {
    LogView()
}
