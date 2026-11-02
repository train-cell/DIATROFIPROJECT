import Foundation
import SwiftUI

/// Simple DI container for dependency injection across the application.
@MainActor
public final class AppContainer: ObservableObject {
    public static let shared = AppContainer()

    public init() {
        // Services will be registered here as milestones progress
    }
}
