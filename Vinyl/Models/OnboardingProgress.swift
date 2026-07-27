import Foundation

enum OnboardingProgress {
    static let currentVersion = 1
    static let completedVersionKey = "Vinyl.onboarding.completedVersion"
    static let currentStepKey = "Vinyl.onboarding.currentStep"
    static let legacyLaunchKey = "Vinyl.hasLaunchedBefore"

    static var isPreviewMode: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--onboarding-preview")
            || ProcessInfo.processInfo.environment["VINYL_ONBOARDING_PREVIEW"] == "1"
#else
        false
#endif
    }

    static func prepare(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: completedVersionKey) == nil else { return }

        // Existing Vinyl users should not be interrupted by a newly introduced
        // first-launch flow. A genuinely fresh install has neither key.
        if defaults.bool(forKey: legacyLaunchKey) {
            defaults.set(currentVersion, forKey: completedVersionKey)
        }
    }

    static func isComplete(defaults: UserDefaults = .standard) -> Bool {
        if isPreviewMode { return false }
        return defaults.integer(forKey: completedVersionKey) >= currentVersion
    }

    static func complete(defaults: UserDefaults = .standard) {
        defaults.set(currentVersion, forKey: completedVersionKey)
        defaults.set(true, forKey: legacyLaunchKey)
        defaults.removeObject(forKey: currentStepKey)
    }

    static func restart(defaults: UserDefaults = .standard) {
        defaults.set(0, forKey: completedVersionKey)
        defaults.set(0, forKey: currentStepKey)
    }
}
