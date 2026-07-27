import SwiftUI

struct TurntableTheme: Identifiable {
    let id: String
    let name: String
    let materials: TurntableMaterials
}

/// The extension point for all new themes. Entries contain materials only;
/// every entry uses the exact same physical turntable and animation machinery.
enum TurntableThemeCatalog {
    static let midnight = TurntableTheme(id:"midnight",name:"Midnight",materials:MidnightMaterials.make())
    static let all: [TurntableTheme] = [midnight]

    static func resolve(_ id: String?) -> TurntableTheme {
        all.first { $0.id == id } ?? midnight
    }
}

/// Keep old theme IDs/appearances usable without extending their geometry switch.
/// New definitions automatically appear in both global and per-display settings.
struct ThemeChoice: Identifiable {
    let id: String
    let name: String
    let family: String

    static var all: [ThemeChoice] {
        TurntableThemeCatalog.all.map { .init(id:"turntable." + $0.id,name:$0.name,family:"Turntable") }
        + VinylTheme.allCases.filter { $0 != .midnight }.map {
            .init(id:"legacy." + $0.rawValue,name:$0.name,family:$0.family)
        }
    }
}

extension AppearanceConfiguration {
    var themeChoiceID: String {
        get {
            if materialThemeID != nil || theme == .midnight {
                return "turntable." + TurntableThemeCatalog.resolve(materialThemeID).id
            }
            return "legacy." + theme.rawValue
        }
        set {
            if newValue.hasPrefix("turntable.") {
                materialThemeID = String(newValue.dropFirst("turntable.".count))
                theme = .midnight
            } else if newValue.hasPrefix("legacy."),
                      let legacy = VinylTheme(rawValue:String(newValue.dropFirst("legacy.".count))) {
                materialThemeID = nil
                theme = legacy
            }
        }
    }

    /// A missing/removed material ID falls back visually without discarding it
    /// from saved preferences, so reinstalling a theme restores the selection.
    var turntableTheme: TurntableTheme { TurntableThemeCatalog.resolve(materialThemeID) }
    var rendererTheme: VinylTheme { materialThemeID == nil ? theme : .midnight }
}
