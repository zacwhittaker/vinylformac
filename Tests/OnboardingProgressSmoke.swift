import Foundation

@main
enum OnboardingProgressSmoke {
    static func main() {
        let suiteName = "Vinyl.OnboardingProgressSmoke.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        precondition(!OnboardingProgress.isComplete(defaults: defaults))

        OnboardingProgress.prepare(defaults: defaults)
        precondition(!OnboardingProgress.isComplete(defaults: defaults))

        defaults.set(3, forKey: OnboardingProgress.currentStepKey)
        OnboardingProgress.complete(defaults: defaults)
        precondition(OnboardingProgress.isComplete(defaults: defaults))
        precondition(defaults.bool(forKey: OnboardingProgress.legacyLaunchKey))
        precondition(defaults.object(forKey: OnboardingProgress.currentStepKey) == nil)

        OnboardingProgress.restart(defaults: defaults)
        precondition(!OnboardingProgress.isComplete(defaults: defaults))
        precondition(defaults.integer(forKey: OnboardingProgress.currentStepKey) == 0)

        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: OnboardingProgress.legacyLaunchKey)
        OnboardingProgress.prepare(defaults: defaults)
        precondition(OnboardingProgress.isComplete(defaults: defaults))

        print("OnboardingProgressSmoke passed")
    }
}
