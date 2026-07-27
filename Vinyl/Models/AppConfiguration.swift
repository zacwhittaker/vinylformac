import Foundation

enum VinylTheme: String, Codable, CaseIterable, Identifiable {
    case midnight, aurora, studio, porcelain, obsidian, transparent
    case hiFi, tokyo, technics, y2k, seventies, braun, walnut, cream, gramophone

    var id: String { rawValue }
    var name: String {
        switch self {
        case .hiFi: "Hi-Fi"
        case .y2k: "Y2K"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
    var family: String {
        switch self {
        case .midnight, .aurora, .studio, .porcelain, .obsidian, .transparent: "Modern"
        case .hiFi, .tokyo, .technics, .y2k: "Modern / Classic"
        default: "Retro"
        }
    }
}

enum VinylMaterial: String, Codable, CaseIterable, Identifiable {
    case black, white, clear, smoke, albumColour, custom
    var id: String { rawValue }
    var name: String { rawValue == "albumColour" ? "Album Colour" : rawValue.capitalized }
}

enum LightingMode: String, Codable, CaseIterable, Identifiable {
    case off, white, warm, albumReactive, custom
    var id: String { rawValue }
    var name: String { rawValue == "albumReactive" ? "Album Reactive" : rawValue.capitalized }
}

enum BackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case pureBlack, solidColour, gradient, albumBlur, albumColours, customImage
    var id: String { rawValue }
    var name: String {
        switch self {
        case .pureBlack: "Pure Black"
        case .solidColour: "Solid Colour"
        case .albumBlur: "Album Blur"
        case .albumColours: "Album Colours"
        case .customImage: "Custom Image"
        default: rawValue.capitalized
        }
    }
}

enum NowPlayingStyle: String, Codable, CaseIterable, Identifiable {
    case minimal, full, floating, hidden
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

enum LayoutMode: String, Codable, CaseIterable, Identifiable {
    case automatic, fullScreen, fitHeight, fitWidth, centre, turntableLeft, turntableRight
    var id: String { rawValue }
    var name: String {
        switch self {
        case .fullScreen: "Full Screen"
        case .fitHeight: "Fit Height"
        case .fitWidth: "Fit Width"
        case .turntableLeft: "Turntable Left"
        case .turntableRight: "Turntable Right"
        default: rawValue.capitalized
        }
    }
}

enum AnimationStyle: String, Codable, CaseIterable, Identifiable {
    case minimal, smooth, physical
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

struct AppearanceConfiguration: Codable, Equatable {
    var theme: VinylTheme = .midnight
    var vinyl: VinylMaterial = .black
    var vinylColour = "#17181B"
    var lighting: LightingMode = .albumReactive
    var lightingColour = "#8AB4FF"
    var lightingIntensity = 0.48
    var platterGlow = true
    var edgeLight = true
    var ambientGlow = true
    var background: BackgroundStyle = .albumColours
    var backgroundColour = "#08090C"
    var nowPlaying: NowPlayingStyle = .full
    var nowPlayingX = 0.82
    var nowPlayingY = 0.52
    var nowPlayingScale = 1.0
    var nowPlayingOpacity = 0.9
    var layout: LayoutMode = .automatic
}

struct DisplayConfiguration: Codable, Equatable, Identifiable {
    var id: String
    var enabled = true
    /// Per-panel rendering calibration. Kept outside `appearance` so sharing
    /// a theme never forces displays with different black levels to match.
    var sceneExposure = 0.0
    var appearance: AppearanceConfiguration
}

struct AnimationConfiguration: Codable, Equatable {
    var style: AnimationStyle = .smooth
    var speed = 1.0
    var tonearmMovement = true
    var spinUpDown = true
    var colourTransitions = true
    var idleLighting = true
    var reduceMotionOverride = false
}

struct AppConfiguration: Codable, Equatable {
    static let currentSchema = 2
    var schemaVersion = currentSchema
    var globalAppearance = AppearanceConfiguration()
    var displayConfigurations: [String: DisplayConfiguration] = [:]
    var useSameAppearanceOnAllDisplays = true
    var animations = AnimationConfiguration()
    var launchAtLogin = false
    var showInMenuBar = true
    var startEnabled = true

    func appearance(for displayID: String) -> AppearanceConfiguration {
        useSameAppearanceOnAllDisplays
            ? globalAppearance
            : displayConfigurations[displayID]?.appearance ?? globalAppearance
    }

    func isEnabled(displayID: String) -> Bool {
        displayConfigurations[displayID]?.enabled ?? true
    }

    func sceneExposure(for displayID: String) -> Double {
        displayConfigurations[displayID]?.sceneExposure ?? 0
    }
}

struct AppearancePreset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var appearance: AppearanceConfiguration

    static let shipped: [AppearancePreset] = [
        .init(name: "Minimal Dark", appearance: .init()),
        .init(name: "Warm Vintage", appearance: .init(theme: .walnut, vinyl: .black, lighting: .warm, lightingIntensity: 0.55, background: .gradient, nowPlaying: .full)),
        .init(name: "Clean Studio", appearance: .init(theme: .studio, vinyl: .black, lighting: .white, lightingIntensity: 0.3, background: .solidColour, nowPlaying: .minimal)),
        .init(name: "Colour Pop", appearance: .init(theme: .aurora, vinyl: .albumColour, lighting: .albumReactive, lightingIntensity: 0.7, background: .albumColours, nowPlaying: .floating)),
        .init(name: "Transparent", appearance: .init(theme: .transparent, vinyl: .smoke, lighting: .white, lightingIntensity: 0.35, background: .pureBlack, nowPlaying: .minimal))
    ]
}

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var configuration: AppConfiguration { didSet { save() } }
    @Published var presets: [AppearancePreset] { didSet { savePresets() } }

    private let defaults: UserDefaults
    private let configKey = "Vinyl.configuration.v2"
    private let presetsKey = "Vinyl.presets.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            configuration = decoded
        } else {
            var migrated = AppConfiguration()
            if defaults.object(forKey: "Vinyl.wallpaperEnabled") != nil {
                migrated.startEnabled = defaults.bool(forKey: "Vinyl.wallpaperEnabled")
            }
            configuration = migrated
        }
        if let data = defaults.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([AppearancePreset].self, from: data) {
            presets = decoded
        } else {
            presets = AppearancePreset.shipped
        }
    }

    func ensureDisplay(_ id: String) {
        guard configuration.displayConfigurations[id] == nil else { return }
        configuration.displayConfigurations[id] = DisplayConfiguration(
            id: id, appearance: configuration.globalAppearance
        )
    }

    func resetAppearance() { configuration.globalAppearance = AppearanceConfiguration() }

    private func save() {
        if let data = try? JSONEncoder().encode(configuration) { defaults.set(data, forKey: configKey) }
    }
    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) { defaults.set(data, forKey: presetsKey) }
    }
}
