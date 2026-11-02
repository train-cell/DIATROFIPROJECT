import SwiftUI

public struct PlanView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(OrchardColors.leafGreen)

                Text("Nutrition & Workout Plan")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(OrchardColors.text)

                Text("View and customize your weekly schedule and templates.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OrchardColors.background)
            .navigationTitle(String(localized: "tab_plan"))
        }
    }
}

#Preview {
    PlanView()
}
