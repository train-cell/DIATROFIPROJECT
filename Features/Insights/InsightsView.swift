import SwiftUI

public struct InsightsView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(OrchardColors.leafGreen)

                Text("Energy & Sleep Insights")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(OrchardColors.text)

                Text("Calorie balance, sleep rating correlations, and adherence.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OrchardColors.background)
            .navigationTitle(String(localized: "tab_insights"))
        }
    }
}

#Preview {
    InsightsView()
}
