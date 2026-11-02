import SwiftUI

#if canImport(OrchardDomain)
import OrchardDomain
#endif

/// Custom vector Shape representing the organic silhouette of an Apple.
public struct AppleShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        // Start at top center notch/dimple
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.16))

        // Upper-left lobe
        path.addCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.16),
            control1: CGPoint(x: w * 0.38, y: h * 0.08),
            control2: CGPoint(x: w * 0.22, y: h * 0.06)
        )

        // Left upper flank / widest point
        path.addCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.55),
            control1: CGPoint(x: w * 0.06, y: h * 0.25),
            control2: CGPoint(x: w * 0.04, y: h * 0.40)
        )

        // Left lower flank curving inward
        path.addCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.94),
            control1: CGPoint(x: w * 0.08, y: h * 0.70),
            control2: CGPoint(x: w * 0.20, y: h * 0.88)
        )

        // Bottom dimple / notch
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.90),
            control1: CGPoint(x: w * 0.42, y: h * 0.97),
            control2: CGPoint(x: w * 0.47, y: h * 0.91)
        )

        // Right lower cheek
        path.addCurve(
            to: CGPoint(x: w * 0.66, y: h * 0.94),
            control1: CGPoint(x: w * 0.53, y: h * 0.91),
            control2: CGPoint(x: w * 0.58, y: h * 0.97)
        )

        // Right upper flank / widest point
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.55),
            control1: CGPoint(x: w * 0.80, y: h * 0.88),
            control2: CGPoint(x: w * 0.92, y: h * 0.70)
        )

        // Right upper lobe
        path.addCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.16),
            control1: CGPoint(x: w * 0.96, y: h * 0.40),
            control2: CGPoint(x: w * 0.94, y: h * 0.25)
        )

        // Back to top center notch
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.16),
            control1: CGPoint(x: w * 0.78, y: h * 0.06),
            control2: CGPoint(x: w * 0.62, y: h * 0.08)
        )

        path.closeSubpath()
        return path
    }
}

/// Vector Shape representing the Apple stem.
public struct AppleStemShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: w * 0.49, y: h * 0.17))
        path.addCurve(
            to: CGPoint(x: w * 0.54, y: h * 0.02),
            control1: CGPoint(x: w * 0.49, y: h * 0.10),
            control2: CGPoint(x: w * 0.51, y: h * 0.05)
        )
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.03))
        path.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.17),
            control1: CGPoint(x: w * 0.55, y: h * 0.06),
            control2: CGPoint(x: w * 0.52, y: h * 0.11)
        )
        path.closeSubpath()
        return path
    }
}

/// Vector Shape representing the Apple leaf.
public struct AppleLeafShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        // Sprouting from stem base
        path.move(to: CGPoint(x: w * 0.53, y: h * 0.11))

        // Upper leaf arc
        path.addCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.04),
            control1: CGPoint(x: w * 0.56, y: h * 0.04),
            control2: CGPoint(x: w * 0.66, y: h * 0.02)
        )

        // Lower leaf arc back to base
        path.addCurve(
            to: CGPoint(x: w * 0.53, y: h * 0.11),
            control1: CGPoint(x: w * 0.70, y: h * 0.10),
            control2: CGPoint(x: w * 0.60, y: h * 0.13)
        )

        path.closeSubpath()
        return path
    }
}

/// Semicircular bite cutout cluster shape simulating tooth marks.
public struct AppleBiteCutoutShape: Shape {
    public var centerRatio: CGPoint
    public var sizeRatio: CGFloat

    public init(
        centerRatio: CGPoint = CGPoint(x: 0.92, y: 0.50),
        sizeRatio: CGFloat = 0.18
    ) {
        self.centerRatio = centerRatio
        self.sizeRatio = sizeRatio
    }

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let cx = centerRatio.x * w
        let cy = centerRatio.y * h
        let r = sizeRatio * min(w, h)

        var path = Path()

        // Main center bite circle
        path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

        // Upper tooth scallop
        let rSub = r * 0.55
        let cyTop = cy - r * 0.65
        let cxTop = cx - r * 0.25
        path.addEllipse(in: CGRect(x: cxTop - rSub, y: cyTop - rSub, width: rSub * 2, height: rSub * 2))

        // Lower tooth scallop
        let cyBottom = cy + r * 0.65
        let cxBottom = cx - r * 0.25
        path.addEllipse(in: CGRect(x: cxBottom - rSub, y: cyBottom - rSub, width: rSub * 2, height: rSub * 2))

        return path
    }
}

/// Radial arc segment representing a meal's slice of the daily apple.
public struct AppleRadialSliceShape: Shape {
    public var startAngleFraction: Double  // 0.0 ... 1.0 (0 to 360 deg)
    public var endAngleFraction: Double    // 0.0 ... 1.0

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngleFraction, endAngleFraction) }
        set {
            startAngleFraction = newValue.first
            endAngleFraction = newValue.second
        }
    }

    public init(startAngleFraction: Double, endAngleFraction: Double) {
        self.startAngleFraction = startAngleFraction
        self.endAngleFraction = endAngleFraction
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width * 0.5, y: rect.height * 0.53)
        let radius = max(rect.width, rect.height)

        let startDeg = (startAngleFraction * 360.0) - 90.0 // Start at top 12 o'clock
        let endDeg = (endAngleFraction * 360.0) - 90.0

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: Angle(degrees: startDeg),
            endAngle: Angle(degrees: endDeg),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// Hero Apple vector view displaying meal slices, eaten calories, and spring bite animations.
public struct HeroAppleView: View {
    public let progress: AppleProgress
    public var biteCount: Int
    public var onBiteTapped: (() -> Void)?

    @State private var isWobbling: Bool = false
    @State private var biteScale: CGFloat = 1.0

    public init(
        progress: AppleProgress,
        biteCount: Int = 0,
        onBiteTapped: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.biteCount = biteCount
        self.onBiteTapped = onBiteTapped
    }

    private var activeBiteCutouts: [CGPoint] {
        guard biteCount > 0 else { return [] }
        // Pre-defined bite spots on the edge
        let positions: [CGPoint] = [
            CGPoint(x: 0.93, y: 0.48), // primary right bite
            CGPoint(x: 0.88, y: 0.32), // upper right bite
            CGPoint(x: 0.85, y: 0.65), // lower right bite
            CGPoint(x: 0.10, y: 0.42), // left bite
            CGPoint(x: 0.14, y: 0.60)  // lower left bite
        ]
        return Array(positions.prefix(min(biteCount, positions.count)))
    }

    public var body: some View {
        ZStack {
            // Background soft glow
            AppleShape()
                .fill(
                    RadialGradient(
                        colors: [
                            OrchardColors.appleRed.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 110
                    )
                )
                .scaleEffect(1.08)

            // Apple Slices & Body with Bite Masking
            ZStack {
                // Base background within apple
                AppleShape()
                    .fill(OrchardColors.appleRed.opacity(0.12))

                // Meal Slices
                if progress.slices.isEmpty {
                    // Empty or rest day fallback fill
                    AppleShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    OrchardColors.leafGreen.opacity(0.6),
                                    OrchardColors.leafGreen.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    ForEach(progress.slices) { slice in
                        AppleRadialSliceShape(
                            startAngleFraction: slice.startAngleFraction,
                            endAngleFraction: slice.endAngleFraction
                        )
                        .fill(sliceColor(for: slice))
                        .clipShape(AppleShape())
                        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: slice.state)
                    }

                    // Slice dividing lines
                    ForEach(progress.slices) { slice in
                        AppleRadialSliceShape(
                            startAngleFraction: slice.startAngleFraction,
                            endAngleFraction: slice.startAngleFraction + 0.003
                        )
                        .fill(Color.white.opacity(0.35))
                        .clipShape(AppleShape())
                    }
                }

                // Apple Surface Shading & Gloss highlight
                AppleShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.black.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )

                // Organic upper-left gloss sheen
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 26)
                    .rotationEffect(.degrees(-35))
                    .offset(x: -42, y: -42)
                    .clipShape(AppleShape())
            }
            .mask {
                // Bite mask using destinationOut
                ZStack {
                    Rectangle()
                        .fill(Color.white)

                    ForEach(activeBiteCutouts.indices, id: \.self) { idx in
                        AppleBiteCutoutShape(
                            centerRatio: activeBiteCutouts[idx],
                            sizeRatio: 0.17
                        )
                        .blendMode(.destinationOut)
                        .scaleEffect(biteScale)
                    }
                }
                .compositingGroup()
            }

            // Stem & Leaf (on top of body)
            AppleStemShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.30, blue: 0.18),
                            Color(red: 0.30, green: 0.18, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            AppleLeafShape()
                .fill(
                    LinearGradient(
                        colors: [
                            OrchardColors.leafGreen,
                            OrchardColors.leafGreen.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)

            // Center Content Display
            VStack(spacing: 2) {
                if progress.totalPlannedKcal > 0 {
                    Text("\(Int(progress.totalEatenKcal))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(centerTextColor)
                        .contentTransition(.numericText())

                    Text("/ \(Int(progress.totalPlannedKcal)) kcal")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(centerSubtextColor)

                    // Percentage pill
                    Text("\(Int(progress.progressFraction * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(centerBadgeBackground)
                        .clipShape(Capsule())
                        .foregroundStyle(centerBadgeTextColor)
                        .padding(.top, 2)
                } else if progress.totalCount > 0 {
                    Text("\(progress.eatenCount)/\(progress.totalCount)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(centerTextColor)

                    Text("γεύματα")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(centerSubtextColor)
                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                    Text("Ανάπαυση")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .offset(y: 8)
        }
        .frame(width: 170, height: 170)
        .scaleEffect(isWobbling ? 0.94 : 1.0)
        .onTapGesture {
            triggerBiteAnimation()
            onBiteTapped?()
        }
        .onChange(of: biteCount) { _, _ in
            triggerBiteAnimation()
        }
    }

    private func triggerBiteAnimation() {
        Haptics.impact(.medium)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
            isWobbling = true
            biteScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                isWobbling = false
                biteScale = 1.0
            }
        }
    }

    private func sliceColor(for slice: AppleSlice) -> Color {
        switch slice.state {
        case .eaten:
            return OrchardColors.appleRed
        case .pending:
            return OrchardColors.appleRed.opacity(0.22)
        case .overdue:
            return Color.orange.opacity(0.85)
        case .skipped:
            return Color.gray.opacity(0.35)
        }
    }

    private var centerTextColor: Color {
        progress.progressFraction > 0.4 ? .white : OrchardColors.text
    }

    private var centerSubtextColor: Color {
        progress.progressFraction > 0.4 ? .white.opacity(0.85) : .secondary
    }

    private var centerBadgeBackground: Color {
        progress.progressFraction > 0.4 ? Color.white.opacity(0.25) : OrchardColors.appleRed.opacity(0.15)
    }

    private var centerBadgeTextColor: Color {
        progress.progressFraction > 0.4 ? .white : OrchardColors.appleRed
    }
}

#Preview {
    let now = Date()
    let slices = [
        AppleSlice(id: "1", itemId: "m1", title: "Πρωινό", plannedKcal: 400, actualKcal: 400, scheduledTime: now, state: .eaten, proportion: 0.25, startAngleFraction: 0.0, endAngleFraction: 0.25),
        AppleSlice(id: "2", itemId: "m2", title: "Δεκατιανό", plannedKcal: 300, scheduledTime: now, state: .overdue, proportion: 0.20, startAngleFraction: 0.25, endAngleFraction: 0.45),
        AppleSlice(id: "3", itemId: "m3", title: "Μεσημεριανό", plannedKcal: 700, scheduledTime: now, state: .pending, proportion: 0.35, startAngleFraction: 0.45, endAngleFraction: 0.80),
        AppleSlice(id: "4", itemId: "m4", title: "Βραδινό", plannedKcal: 400, scheduledTime: now, state: .pending, proportion: 0.20, startAngleFraction: 0.80, endAngleFraction: 1.0)
    ]
    let progress = AppleProgress(slices: slices)

    return HeroAppleView(progress: progress, biteCount: 1)
        .padding(40)
        .background(OrchardColors.background)
}
