import SwiftUI

private struct DisplayRefreshRateKey: EnvironmentKey {
    static let defaultValue = 60.0
}

extension EnvironmentValues {
    var displayRefreshRate: Double {
        get { self[DisplayRefreshRateKey.self] }
        set { self[DisplayRefreshRateKey.self] = newValue }
    }
}
