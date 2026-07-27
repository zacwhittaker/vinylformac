import Foundation
import SwiftUI

@main
struct ThemeConfigurationSmoke {
    @MainActor static func main() throws {
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        var original = AppConfiguration()
        original.globalAppearance.theme = .walnut
        original.globalAppearance.nowPlayingOpacity = 0.63
        original.displayConfigurations["test"] = DisplayConfiguration(id:"test",sceneExposure:0.27,appearance:.init(theme:.studio))
        // A nil optional is omitted by JSONEncoder, reproducing the old schema-v2 file.
        let oldData = try encoder.encode(original)
        let decoded = try decoder.decode(AppConfiguration.self,from:oldData)
        precondition(decoded == original)
        precondition(decoded.globalAppearance.rendererTheme == .walnut)
        precondition(AppearanceConfiguration().rendererTheme == .midnight)
        precondition(AppearanceConfiguration().turntableTheme.id == "midnight")

        var selected = decoded
        selected.globalAppearance.themeChoiceID = "turntable.midnight"
        precondition(selected.globalAppearance.rendererTheme == .midnight)
        precondition(selected.globalAppearance.nowPlayingOpacity == 0.63)
        precondition(selected.sceneExposure(for:"test") == 0.27)
        precondition(decoded.differsOnlyInAppearance(from:selected))
        selected.globalAppearance.materialThemeID = "future-material"
        precondition(selected.globalAppearance.turntableTheme.id == "midnight")
        precondition(selected.globalAppearance.rendererTheme == .midnight)
        let restored = try decoder.decode(AppConfiguration.self,from:encoder.encode(selected))
        precondition(restored == selected && restored.globalAppearance.materialThemeID == "future-material")
        selected.globalAppearance.themeChoiceID = "legacy.aurora"
        precondition(selected.globalAppearance.materialThemeID == nil)
        precondition(selected.globalAppearance.rendererTheme == .aurora)
        selected.displayConfigurations["test"]?.appearance.themeChoiceID = "turntable.midnight"
        selected.useSameAppearanceOnAllDisplays = false
        precondition(selected.appearance(for:"test").rendererTheme == .midnight)
        precondition(decoded.differsOnlyInAppearance(from:selected))
        var policyChange = selected
        policyChange.gameModeEnabled = true
        precondition(!selected.differsOnlyInAppearance(from:policyChange))
        policyChange = selected
        policyChange.animations.idleDelay = 20
        precondition(!selected.differsOnlyInAppearance(from:policyChange))
        policyChange = selected
        policyChange.displayConfigurations["test"]?.sceneExposure = 0.4
        precondition(!selected.differsOnlyInAppearance(from:policyChange))
        policyChange = selected
        policyChange.displayConfigurations["test"]?.enabled = false
        precondition(!selected.differsOnlyInAppearance(from:policyChange))
        let preset = AppearancePreset(name:"Saved material",appearance:restored.globalAppearance)
        let restoredPreset = try decoder.decode(AppearancePreset.self,from:encoder.encode(preset))
        precondition(restoredPreset == preset)
        precondition(Set(ThemeChoice.all.map(\.id)).count == ThemeChoice.all.count)
        precondition(Set(TurntableThemeCatalog.all.map(\.id)).count == TurntableThemeCatalog.all.count)
        precondition(ThemeChoice.all.first?.id == "turntable.midnight")
        print("Theme configuration passed: legacy decode, defaults, selection, unknown-ID fallback, presets, displays and in-place update policy")
    }
}
