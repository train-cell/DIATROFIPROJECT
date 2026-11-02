import SwiftUI

public struct TodayView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Hero Apple placeholder
                ZStack {
                    Circle()
                        .fill(OrchardColors.appleRed.opacity(0.15))
                        .frame(width: 160, height: 160)

                    Image(systemName: "apple.logo")
                        .font(.system(size: 80))
                        .foregroundStyle(OrchardColors.appleRed)
                }

                VStack(spacing: 8) {
                    Text("Orchard")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(OrchardColors.text)

                    Text("Welcome to your personal nutrition & rhythm assistant.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OrchardColors.background)
            .navigationTitle(String(localized: "tab_today"))
        }
    }
}

#Preview {
    TodayView()
}
