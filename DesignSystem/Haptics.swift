import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Tactile feedback generator for Orchard UI interactions.
@MainActor
public enum Haptics {

    /// Triggers success haptic notification (e.g. confirming a meal log).
    public static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Triggers warning haptic notification (e.g. schedule conflict or overdue meal).
    public static func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// Triggers error haptic notification.
    public static func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }

    /// Triggers subtle selection tick (e.g. changing template chips).
    public static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    /// Triggers light or medium impact feedback.
    public static func impact(_ style: ImpactStyle = .medium) {
        #if os(iOS)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: uiStyle = .light
        case .medium: uiStyle = .medium
        case .heavy: uiStyle = .heavy
        case .rigid: uiStyle = .rigid
        case .soft: uiStyle = .soft
        }
        let generator = UIImpactFeedbackGenerator(style: uiStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    public enum ImpactStyle: Sendable {
        case light
        case medium
        case heavy
        case rigid
        case soft
    }
}
