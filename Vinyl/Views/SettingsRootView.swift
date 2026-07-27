import AppKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance = "Appearance", player = "Player", deck = "Vinyl & Deck", lighting = "Lighting"
    case background = "Background", nowPlaying = "Now Playing", displays = "Displays"
    case animations = "Animations", shortcuts = "Shortcuts", general = "General", about = "About"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .appearance: "paintpalette"; case .player: "play.circle"; case .deck: "record.circle"
        case .lighting: "lightbulb"; case .background: "photo"; case .nowPlaying: "music.note.list"
        case .displays: "display.2"; case .animations: "waveform.path"; case .shortcuts: "command"
        case .general: "gearshape"; case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SettingsSection? = .appearance

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }
            .navigationTitle("Vinyl")
            .frame(minWidth: 190)
        } detail: {
            VStack(spacing: 0) {
                LivePreview(item: previewItem, appearance: appearance, animation: store.configuration.animations)
                    .frame(height: 300)
                    .padding(24)
                Divider()
                ScrollView { sectionView.padding(28).frame(maxWidth: 820, alignment: .topLeading) }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 960, minHeight: 720)
    }

    private var store: ConfigurationStore { model.configurationStore }
    private var appearance: AppearanceConfiguration { store.configuration.globalAppearance }
    private var previewItem: PlayingItem {
        model.currentItem ?? PlayingItem(id: "vinyl-preview", title: "A Quiet Moment", artist: "Vinyl", collection: "Desktop Sessions", artworkURL: nil, spotifyURL: nil, isPlaying: true, progressMilliseconds: 82_000, durationMilliseconds: 240_000)
    }

    @ViewBuilder private var sectionView: some View {
        switch selection ?? .appearance {
        case .appearance: AppearanceSettings(store: store)
        case .player: PlayerSettings(model: model)
        case .deck: DeckSettings(store: store)
        case .lighting: LightingSettings(store: store)
        case .background: BackgroundSettings(store: store)
        case .nowPlaying: NowPlayingSettings(store: store)
        case .displays: DisplaySettings(model: model)
        case .animations: AnimationSettings(store: store)
        case .shortcuts: ShortcutSettings()
        case .general: GeneralSettings(model: model)
        case .about: AboutSettings()
        }
    }
}

private struct LivePreview: View {
    let item: PlayingItem
    let appearance: AppearanceConfiguration
    let animation: AnimationConfiguration
    var body: some View {
        ModernWallpaperView(item: item, snapshotDate: .now, appearance: appearance, animation: animation)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator.opacity(0.6)))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            .accessibilityLabel("Live desktop preview")
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { Text(title).font(.headline); content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 18)
    }
}

private struct AppearanceSettings: View {
    @ObservedObject var store: ConfigurationStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroup(title: "Theme") {
                ForEach(["Modern", "Modern / Classic", "Retro"], id: \.self) { family in
                    Text(family).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                        ForEach(VinylTheme.allCases.filter { $0.family == family }) { theme in
                            Button { store.configuration.globalAppearance.theme = theme } label: {
                                HStack { Image(systemName: store.configuration.globalAppearance.theme == theme ? "checkmark.circle.fill" : "circle"); Text(theme.name); Spacer() }
                                    .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain).accessibilityLabel("\(theme.name) theme")
                        }
                    }
                }
            }
            HStack {
                Menu("Presets") { ForEach(store.presets) { preset in Button(preset.name) { store.configuration.globalAppearance = preset.appearance } } }
                Button("Save as Preset") { store.presets.append(.init(name: "My Preset \(store.presets.count + 1)", appearance: store.configuration.globalAppearance)) }
                Spacer()
                Button("Reset to Default") { store.resetAppearance() }
            }
            SettingsGroup(title: "Saved presets") {
                ForEach($store.presets) { $preset in
                    HStack {
                        TextField("Preset name", text: $preset.name)
                        Button("Apply") { store.configuration.globalAppearance = preset.appearance }
                        Button { store.presets.append(.init(name: "\(preset.name) Copy", appearance: preset.appearance)) } label: { Image(systemName: "plus.square.on.square") }
                            .help("Duplicate preset")
                        Button(role: .destructive) { store.presets.removeAll { $0.id == preset.id } } label: { Image(systemName: "trash") }
                            .help("Delete preset")
                    }
                }
            }
        }
    }
}

private struct PlayerSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SettingsGroup(title: "Playback source") {
            LabeledContent("Spotify") { Label(model.isSpotifyRunning ? "Connected" : "Not running", systemImage: model.isSpotifyRunning ? "checkmark.circle.fill" : "circle") }
            Text("Vinyl listens locally for Spotify playback changes. Apple Music is not yet implemented in this upstream codebase.").foregroundStyle(.secondary)
            Button("Refresh Spotify") { model.refresh() }
        }
    }
}

private struct DeckSettings: View {
    @ObservedObject var store: ConfigurationStore
    var body: some View {
        VStack(alignment: .leading) {
            SettingsGroup(title: "Vinyl") {
                Picker("Material", selection: binding(\.vinyl)) { ForEach(VinylMaterial.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 380)
            }
            SettingsGroup(title: "Composition") {
                Picker("Layout", selection: binding(\.layout)) { ForEach(LayoutMode.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 380)
                Text("Automatic uses purpose-built portrait, standard, and ultrawide compositions.").foregroundStyle(.secondary)
            }
        }
    }
    private func binding<T>(_ keyPath: WritableKeyPath<AppearanceConfiguration, T>) -> Binding<T> { Binding(get: { store.configuration.globalAppearance[keyPath: keyPath] }, set: { store.configuration.globalAppearance[keyPath: keyPath] = $0 }) }
}

private struct LightingSettings: View {
    @ObservedObject var store: ConfigurationStore
    var body: some View {
        SettingsGroup(title: "Lighting") {
            Picker("Mode", selection: binding(\.lighting)) { ForEach(LightingMode.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 380)
            LabeledContent("Intensity") { Slider(value: binding(\.lightingIntensity), in: 0...1).frame(width: 260) }
            Toggle("Platter glow", isOn: binding(\.platterGlow)); Toggle("Edge light", isOn: binding(\.edgeLight)); Toggle("Ambient glow", isOn: binding(\.ambientGlow))
            Text("Album Reactive changes colour smoothly using a stable palette derived from the current track.").foregroundStyle(.secondary)
        }
    }
    private func binding<T>(_ keyPath: WritableKeyPath<AppearanceConfiguration, T>) -> Binding<T> { Binding(get: { store.configuration.globalAppearance[keyPath: keyPath] }, set: { store.configuration.globalAppearance[keyPath: keyPath] = $0 }) }
}

private struct BackgroundSettings: View {
    @ObservedObject var store: ConfigurationStore
    var body: some View {
        SettingsGroup(title: "Desktop background") {
            Picker("Style", selection: binding(\.background)) {
                ForEach(BackgroundStyle.allCases.filter { $0 != .customImage }) { Text($0.name).tag($0) }
            }.frame(maxWidth: 380)
            Text("Album Blur and Album Colours are rendered once from shared artwork rather than processed every frame.").foregroundStyle(.secondary)
        }
    }
    private func binding<T>(_ keyPath: WritableKeyPath<AppearanceConfiguration, T>) -> Binding<T> { Binding(get: { store.configuration.globalAppearance[keyPath: keyPath] }, set: { store.configuration.globalAppearance[keyPath: keyPath] = $0 }) }
}

private struct NowPlayingSettings: View {
    @ObservedObject var store: ConfigurationStore
    var body: some View {
        SettingsGroup(title: "Now Playing") {
            Picker("Style", selection: binding(\.nowPlaying)) { ForEach(NowPlayingStyle.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 380)
            LabeledContent("Scale") { Slider(value: binding(\.nowPlayingScale), in: 0.65...1.4).frame(width: 260) }
            LabeledContent("Opacity") { Slider(value: binding(\.nowPlayingOpacity), in: 0.25...1).frame(width: 260) }
        }
    }
    private func binding<T>(_ keyPath: WritableKeyPath<AppearanceConfiguration, T>) -> Binding<T> { Binding(get: { store.configuration.globalAppearance[keyPath: keyPath] }, set: { store.configuration.globalAppearance[keyPath: keyPath] = $0 }) }
}

private struct DisplaySettings: View {
    @ObservedObject var model: AppModel
    @State private var selectedDisplayID: String?
    private var store: ConfigurationStore { model.configurationStore }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Connected displays").font(.headline); Spacer(); Button("Identify Displays") { model.displayManager.identifyDisplays() } }
            Toggle("Use same appearance on all displays", isOn: Binding(get: { store.configuration.useSameAppearanceOnAllDisplays }, set: { store.configuration.useSameAppearanceOnAllDisplays = $0 }))
            ForEach(model.displayManager.displays) { display in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Image(systemName: display.isPortrait ? "rectangle.portrait" : "display")
                        VStack(alignment: .leading) { Text(display.name).font(.headline); Text("\(display.resolution) · \(display.orientationName) · \(String(format: "%.1f×", display.scale))").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Toggle("Vinyl", isOn: enabledBinding(display.id)).toggleStyle(.switch)
                    }
                    if !store.configuration.useSameAppearanceOnAllDisplays {
                        Picker("Theme", selection: displayThemeBinding(display.id)) { ForEach(VinylTheme.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 340)
                        Picker("Layout", selection: displayLayoutBinding(display.id)) { ForEach(LayoutMode.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 340)
                    }
                    LabeledContent("Scene Exposure") {
                        HStack(spacing: 10) {
                            Slider(value: displayExposureBinding(display.id), in: -0.20...0.40)
                                .frame(width: 220)
                            Text(displayExposureLabel(display.id))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                    Text("Lifts dark material detail for this display while protecting highlights.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Disconnected display settings are retained and restored when the same display returns.").foregroundStyle(.secondary)
        }
    }
    private func enabledBinding(_ id: String) -> Binding<Bool> { Binding(get: { store.configuration.displayConfigurations[id]?.enabled ?? true }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.enabled = $0 }) }
    private func displayThemeBinding(_ id: String) -> Binding<VinylTheme> { Binding(get: { store.configuration.displayConfigurations[id]?.appearance.theme ?? store.configuration.globalAppearance.theme }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.appearance.theme = $0 }) }
    private func displayLayoutBinding(_ id: String) -> Binding<LayoutMode> { Binding(get: { store.configuration.displayConfigurations[id]?.appearance.layout ?? .automatic }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.appearance.layout = $0 }) }
    private func displayExposureBinding(_ id: String) -> Binding<Double> { Binding(get: { store.configuration.sceneExposure(for: id) }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.sceneExposure = $0 }) }
    private func displayExposureLabel(_ id: String) -> String { String(format: "%+.0f%%", store.configuration.sceneExposure(for: id) * 100) }
}

private struct AnimationSettings: View {
    @ObservedObject var store: ConfigurationStore
    var body: some View {
        SettingsGroup(title: "Motion") {
            Picker("Style", selection: binding(\.style)) { ForEach(AnimationStyle.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 380)
            LabeledContent("Speed") { Slider(value: binding(\.speed), in: 0.5...2).frame(width: 260) }
            Toggle("Tonearm movement", isOn: binding(\.tonearmMovement)); Toggle("Spin up and down", isOn: binding(\.spinUpDown)); Toggle("Album-reactive colour transitions", isOn: binding(\.colourTransitions)); Toggle("Idle lighting", isOn: binding(\.idleLighting)); Toggle("Always reduce motion", isOn: binding(\.reduceMotionOverride))
            Text("The macOS Reduce Motion accessibility setting is respected automatically.").foregroundStyle(.secondary)
        }
    }
    private func binding<T>(_ keyPath: WritableKeyPath<AnimationConfiguration, T>) -> Binding<T> { Binding(get: { store.configuration.animations[keyPath: keyPath] }, set: { store.configuration.animations[keyPath: keyPath] = $0 }) }
}

private struct ShortcutSettings: View {
    var body: some View { SettingsGroup(title: "Keyboard shortcuts") { LabeledContent("Toggle desktop Vinyl", value: "⌘D"); LabeledContent("Refresh playback", value: "⌘R"); Text("Global shortcuts are intentionally not registered, avoiding conflicts with other apps.").foregroundStyle(.secondary) } }
}

private struct GeneralSettings: View {
    @ObservedObject var model: AppModel
    private var store: ConfigurationStore { model.configurationStore }
    var body: some View {
        SettingsGroup(title: "Startup") {
            Toggle("Launch at Login", isOn: Binding(get: { store.configuration.launchAtLogin }, set: { store.configuration.launchAtLogin = $0 }))
            Toggle("Start Vinyl automatically", isOn: Binding(get: { store.configuration.startEnabled }, set: { store.configuration.startEnabled = $0 }))
            Toggle("Vinyl enabled", isOn: Binding(get: { model.isWallpaperEnabled }, set: { model.setWallpaperEnabled($0) }))
            Text("No analytics or telemetry are included.").foregroundStyle(.secondary)
        }
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "record.circle.fill").font(.system(size: 64)).symbolRenderingMode(.hierarchical)
            Text("Vinyl").font(.largeTitle.bold()); Text("A modern turntable for your Mac desktop.").font(.title3)
            Text("This project is independently implemented. Its desktop-window approach was informed by the GPL-3.0 Luviosa project; no Luviosa source or media is included.").foregroundStyle(.secondary)
            Link("View project documentation", destination: URL(string: "https://github.com")!)
        }
    }
}
