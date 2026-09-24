import AppKit
import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject private var model: AppModel
<<<<<<< HEAD
    var initialPage: SettingsPage = .appearance

    var body: some View {
        SettingsContent(model: model, store: model.configurationStore, initialPage: initialPage)
    }
}

enum SettingsPage: String, CaseIterable {
    case appearance = "Appearance"
    case displays = "Displays"
    case general = "General"

    var icon: String {
        switch self {
        case .appearance: "paintpalette.fill"
        case .displays: "display.2"
        case .general: "gearshape.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .appearance: "Shape the atmosphere of your turntable."
        case .displays: "Give every screen its own perfect presentation."
        case .general: "Choose how Vinyl works with your Mac and music."
        }
    }

    var accent: Color {
        switch self {
        case .appearance: Color(red: 0.98, green: 0.27, blue: 0.34)
        case .displays: Color(red: 0.24, green: 0.55, blue: 0.98)
        case .general: Color(red: 0.55, green: 0.42, blue: 0.98)
        }
=======

    var body: some View {
        SettingsContent(model: model, store: model.configurationStore)
>>>>>>> 10bb768fe8843589f7fb9f1375d2e6e8eaec9fb6
    }
}

private struct SettingsContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: ConfigurationStore
<<<<<<< HEAD
    @AppStorage(OnboardingProgress.completedVersionKey) private var completedOnboardingVersion = OnboardingProgress.currentVersion
    @State private var selection: SettingsPage
    @State private var searchText = ""

    init(model: AppModel, store: ConfigurationStore, initialPage: SettingsPage) {
        self.model = model
        self.store = store
        _selection = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            SettingsBackdrop(accent: selection.accent)

            HStack(spacing: 14) {
                SettingsSidebar(selection: $selection, searchText: $searchText)
                    .frame(width: 224)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SettingsPageHeader(page: selection)

                        Group {
                            switch selection {
                            case .appearance:
                                appearancePage
                            case .displays:
                                DisplaySettings(store: store, displays: model.displayManager)
                            case .general:
                                generalPage
                            }
                        }
                        .id(selection)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    .frame(maxWidth: 780, alignment: .leading)
                    .padding(26)
                }
                .scrollIndicators(.hidden)
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(14)
        }
        .animation(.snappy(duration: 0.28), value: selection)
        .frame(minWidth: 820, idealWidth: 980, minHeight: 640, idealHeight: 740)
    }

    private var appearancePage: some View {
        SettingsGlassContainer(spacing: 18) {
            VStack(spacing: 18) {
                ThemeGallery()

                SettingsGroup(
                    title: "Lighting",
                    subtitle: "A restrained glow drawn from the current album artwork.",
                    icon: "lightbulb.max.fill",
                    tint: SettingsPage.appearance.accent
                ) {
                    SettingsToggleRow(
                        title: "Platter glow",
                        detail: "Illuminate the record and tonearm with the album colour.",
                        isOn: appearance(\.platterGlow)
                    )
                    SettingsDivider()
                    SettingsSlider(
                        "Intensity",
                        detail: "Control the strength of the reactive lighting.",
                        value: appearance(\.lightingIntensity),
                        range: 0...1
                    )
                    .disabled(!store.configuration.globalAppearance.platterGlow)
                }

                SettingsGroup(
                    title: "Now playing",
                    subtitle: "Keep track information present without overpowering the turntable.",
                    icon: "music.note.list",
                    tint: SettingsPage.appearance.accent
                ) {
                    SettingsToggleRow(
                        title: "Show track information",
                        detail: "Display artwork, title, artist and progress on the deck.",
                        isOn: Binding(
                            get: { store.configuration.globalAppearance.nowPlaying != .hidden },
                            set: { store.configuration.globalAppearance.nowPlaying = $0 ? .full : .hidden }
                        )
                    )
                    SettingsDivider()
                    SettingsSlider(
                        "Opacity",
                        detail: "Balance readability against the smoked-glass housing.",
                        value: appearance(\.nowPlayingOpacity),
                        range: 0.25...1
                    )
                    .disabled(store.configuration.globalAppearance.nowPlaying == .hidden)
                }

                SettingsFooter(
                    message: store.configuration.useSameAppearanceOnAllDisplays
                        ? "Changes are applied to every display."
                        : "Display-specific appearance is enabled.",
                    actionTitle: "Reset Midnight",
                    action: { store.resetAppearance() }
                )
            }
        }
    }

    private var generalPage: some View {
        SettingsGlassContainer(spacing: 18) {
            VStack(spacing: 18) {
                SettingsGroup(
                    title: "Music source",
                    subtitle: "Vinyl follows one desktop player at a time.",
                    icon: "music.note",
                    tint: SettingsPage.general.accent
                ) {
                    Picker("Music player", selection: Binding(
                        get: { model.selectedPlayer },
                        set: { model.selectPlayer($0) }
                    )) {
                        ForEach(MusicPlayer.allCases) { player in
                            Text(player.name).tag(player)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    HStack(spacing: 9) {
                        Image(systemName: model.isPlayerRunning ? "waveform" : "waveform.slash")
                            .foregroundStyle(model.isPlayerRunning ? .green : .secondary)
                        Text(model.statusMessage)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text(model.selectedPlayer.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))

                    Text("Allow Automation access when macOS asks so Vinyl can read playback and control the selected app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }

                SettingsGroup(
                    title: "Desktop & startup",
                    subtitle: "Choose when and where the turntable appears.",
                    icon: "macwindow",
                    tint: SettingsPage.general.accent
                ) {
                    SettingsToggleRow(
                        title: "Show Vinyl on desktop",
                        detail: "Display the turntable behind your windows.",
                        isOn: Binding(
                            get: { model.isWallpaperEnabled },
                            set: { model.setWallpaperEnabled($0) }
                        )
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Show desktop on startup",
                        detail: "Restore the desktop turntable when Vinyl starts.",
                        isOn: $store.configuration.startEnabled
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Launch at login",
                        detail: "Open Vinyl automatically after you sign in.",
                        isOn: $store.configuration.launchAtLogin
                    )
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Game Mode",
                        detail: "Keep Vinyl in the current Space and out of full-screen apps.",
                        isOn: Binding(
                            get: { store.configuration.gameModeEnabled ?? false },
                            set: { store.configuration.gameModeEnabled = $0 }
                        )
                    )
                }

                SettingsGroup(
                    title: "Motion",
                    subtitle: "Tune physical movement and accessibility behaviour.",
                    icon: "move.3d",
                    tint: SettingsPage.general.accent
                ) {
                    SettingsToggleRow(
                        title: "Move tonearm",
                        detail: "Animate the arm between its rest and the record.",
                        isOn: $store.configuration.animations.tonearmMovement
                    )
                    SettingsDivider()
                    SettingsSlider(
                        "Park after pausing",
                        detail: "Wait before returning the tonearm to its rest.",
                        value: $store.configuration.animations.idleDelay,
                        range: 5...120,
                        step: 1,
                        format: { "\(Int($0)) sec" }
                    )
                    .disabled(!store.configuration.animations.tonearmMovement)
                    SettingsDivider()
                    SettingsToggleRow(
                        title: "Reduce motion",
                        detail: "Also follows your Mac’s accessibility setting.",
                        isOn: $store.configuration.animations.reduceMotionOverride
                    )
                }

                SettingsGroup(
                    title: "Setup assistant",
                    subtitle: "Review the choices Vinyl made during first-time setup.",
                    icon: "wand.and.stars",
                    tint: SettingsPage.general.accent
                ) {
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Run setup again")
                                .font(.callout.weight(.medium))
                            Text("Revisit your player, theme and display choices. Your current settings stay selected.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 20)
                        Button("Open Setup") {
                            OnboardingProgress.restart()
                            completedOnboardingVersion = 0
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func appearance<T>(_ keyPath: WritableKeyPath<AppearanceConfiguration, T>) -> Binding<T> {
        Binding(
            get: { store.configuration.globalAppearance[keyPath: keyPath] },
            set: { store.configuration.globalAppearance[keyPath: keyPath] = $0 }
        )
    }
}

private struct SettingsBackdrop: View {
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                if !reduceTransparency {
                    Image("MidnightThemeCover")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blur(radius: 62)
                        .scaleEffect(1.18)
                        .saturation(0.72)
                        .opacity(colorScheme == .dark ? 0.34 : 0.15)

                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.2 : 0.12))
                        .frame(width: proxy.size.width * 0.65)
                        .blur(radius: 110)
                        .offset(x: proxy.size.width * 0.27, y: -proxy.size.height * 0.35)
                }

                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.2 : 0.5),
                        Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.62 : 0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipped()
        }
        .ignoresSafeArea()
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsPage
    @Binding var searchText: String

    private var visiblePages: [SettingsPage] {
        guard !searchText.isEmpty else { return SettingsPage.allCases }
        return SettingsPage.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
                || $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image("VinylLogo")
                    .resizable()
                    .interpolation(.high)
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Vinyl").font(.headline)
                    Text("Made for the music")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search Settings", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search settings")
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 7) {
                ForEach(visiblePages, id: \.self) { page in
                    Button { selection = page } label: {
                        HStack(spacing: 11) {
                            Image(systemName: page.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selection == page ? page.accent : .secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    (selection == page ? page.accent : Color.primary)
                                        .opacity(selection == page ? 0.15 : 0.05),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            Text(page.rawValue)
                                .font(.system(size: 14, weight: selection == page ? .semibold : .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(SettingsNavigationButtonStyle(isSelected: selection == page, tint: page.accent))
                    .accessibilityAddTraits(selection == page ? .isSelected : [])
                }
            }

            if visiblePages.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search.")
                )
                .controlSize(.small)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 7) {
                Label("Midnight", systemImage: "moon.stars.fill")
                    .font(.caption.weight(.semibold))
                Text("Your active desktop theme")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
        }
        .padding(18)
        .settingsGlass(cornerRadius: 28)
    }
}

private struct SettingsNavigationButtonStyle: ButtonStyle {
    let isSelected: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.13) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.2) : .clear)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct SettingsPageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: page.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(page.accent)
                .frame(width: 48, height: 48)
                .background(page.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 3) {
                Text(page.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(page.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

private struct ThemeGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme library").font(.headline)
                    Text("Midnight is installed and ready.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label("1 available", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                Image("MidnightThemeCover")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 300, height: 188)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.13))
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SettingsPage.appearance.accent)
                    Text("Midnight")
                        .font(.title2.bold())
                    Text("Graphite metal, smoked glass and album-reactive light.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text("Included")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .settingsGlass(cornerRadius: 24, tint: SettingsPage.appearance.accent.opacity(0.07), interactive: true)

            HStack(spacing: 10) {
                ForEach(2...6, id: \.self) { number in
                    VStack(spacing: 7) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%02d", number))
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.separator.opacity(0.16))
                    }
                    .accessibilityLabel("Theme \(number), coming soon")
                }
            }
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                content
            }
        }
        .padding(18)
        .settingsGlass(cornerRadius: 22, tint: tint.opacity(0.035))
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 10)
    }
}

private struct SettingsSlider: View {
    let title: String
    let detail: String
=======
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings section", selection: $selection) {
                Label("Appearance", systemImage: "paintpalette").tag(0)
                Label("Displays", systemImage: "display.2").tag(1)
                Label("General", systemImage: "gearshape").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(20)
            Divider()
            if selection == 0 {
            Form {
                Section {
                    Picker("Theme", selection: appearance(\.themeChoiceID)) {
                        ForEach(ThemeChoice.all) { Text($0.name).tag($0.id) }
                    }
                    Text(store.configuration.useSameAppearanceOnAllDisplays
                         ? "Changes apply to your desktop automatically."
                         : "Displays use individual themes. Enable shared appearance in Displays to apply these controls everywhere.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Lighting") {
                    Toggle("Platter glow", isOn: appearance(\.platterGlow))
                    SettingsSlider("Glow intensity", value: appearance(\.lightingIntensity), range: 0...1)
                        .disabled(!store.configuration.globalAppearance.platterGlow)
                }
                Section("Track information") {
                    Toggle("Show track information", isOn: Binding(
                        get: { store.configuration.globalAppearance.nowPlaying != .hidden },
                        set: { store.configuration.globalAppearance.nowPlaying = $0 ? .full : .hidden }
                    ))
                    SettingsSlider("Opacity", value: appearance(\.nowPlayingOpacity), range: 0.25...1)
                        .disabled(store.configuration.globalAppearance.nowPlaying == .hidden)
                    if store.configuration.globalAppearance.rendererTheme != .midnight {
                        SettingsSlider("Size", value: appearance(\.nowPlayingScale), range: 0.65...1.4)
                    }
                }
                if store.configuration.globalAppearance.rendererTheme != .midnight {
                    Section("Composition") {
                        Picker("Record colour", selection: appearance(\.vinyl)) {
                            ForEach(VinylMaterial.allCases.filter { $0 != .custom }) { Text($0.name).tag($0) }
                        }
                        Picker("Layout", selection: appearance(\.layout)) {
                            ForEach(LayoutMode.allCases) { Text($0.name).tag($0) }
                        }
                        Picker("Background", selection: appearance(\.background)) {
                            ForEach(BackgroundStyle.allCases.filter { $0 != .customImage }) { Text($0.name).tag($0) }
                        }
                    }
                }
                Section {
                    DisclosureGroup("Presets") {
                        ForEach($store.presets) { $preset in
                            HStack {
                                TextField("Preset name", text: $preset.name)
                                Button("Apply") { model.applyPreset(preset) }
                                Button(role: .destructive) { store.presets.removeAll { $0.id == preset.id } } label: {
                                    Image(systemName: "trash")
                                }.help("Delete preset")
                            }
                        }
                        Button("Save current appearance") {
                            store.presets.append(.init(name: "My Preset \(store.presets.count + 1)", appearance: store.configuration.globalAppearance))
                        }
                    }
                    Button("Reset appearance") { store.resetAppearance() }
                }
            }
            } else if selection == 1 {

            ScrollView {
                DisplaySettings(model: model, store: store, displays: model.displayManager)
                    .padding(24)
            }
            } else {

            Form {
                Section("Desktop") {
                    Toggle("Show Vinyl on desktop", isOn: Binding(get: { model.isWallpaperEnabled }, set: { model.setWallpaperEnabled($0) }))
                    Toggle("Show desktop on startup", isOn: $store.configuration.startEnabled)
                    Toggle("Launch at login", isOn: $store.configuration.launchAtLogin)
                    Toggle("Game Mode", isOn: Binding(get: { store.configuration.gameModeEnabled ?? false }, set: { store.configuration.gameModeEnabled = $0 }))
                    Text("Game Mode keeps Vinyl in the current Space and out of full-screen apps.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Motion") {
                    Toggle("Move tonearm", isOn: $store.configuration.animations.tonearmMovement)
                    SettingsSlider("Park after pausing", value: $store.configuration.animations.idleDelay, range: 5...120, step: 1, format: { "\(Int($0)) sec" })
                        .disabled(!store.configuration.animations.tonearmMovement)
                    Toggle("Reduce motion", isOn: $store.configuration.animations.reduceMotionOverride)
                    Text("The macOS Reduce Motion setting is also respected.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Spotify") {
                    LabeledContent("Status", value: model.isSpotifyRunning ? "Spotify is running" : "Open Spotify to play music")
                    Button("Refresh playback") { model.refresh() }.disabled(model.isRefreshing)
                }
                Section("Vinyl") {
                    Text("A turntable for your Mac desktop.")
                    LabeledContent("Settings", value: "⌘,")
                    LabeledContent("Show or hide desktop", value: "⌘D")
                    LabeledContent("Refresh playback", value: "⌘R")
                }
            }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .frame(minWidth: 620, idealWidth: 680, minHeight: 620, idealHeight: 700)
    }

    private func appearance<T>(_ keyPath: WritableKeyPath<AppearanceConfiguration, T>) -> Binding<T> {
        Binding(get: { store.configuration.globalAppearance[keyPath: keyPath] },
                set: { store.configuration.globalAppearance[keyPath: keyPath] = $0 })
    }
}

/// Keep the thumb and value local during a drag. Persist/apply once on release;
/// keyboard and accessibility adjustments commit immediately.
private struct SettingsSlider: View {
    let title: String
>>>>>>> 10bb768fe8843589f7fb9f1375d2e6e8eaec9fb6
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    var format: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
    @State private var draft: Double = 0
    @State private var editing = false

<<<<<<< HEAD
    init(
        _ title: String,
        detail: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01,
        format: @escaping (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
    ) {
        self.title = title
        self.detail = detail
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { editing ? draft : value },
                        set: {
                            draft = min(range.upperBound, max(range.lowerBound, ($0 / step).rounded() * step))
                            if !editing { value = draft }
                        }
                    ),
                    in: range,
                    onEditingChanged: { active in
                        if active {
                            draft = value
                            editing = true
                        } else {
                            editing = false
                            value = draft
                        }
                    }
                )
                .accessibilityLabel(title)
                Text(format(editing ? draft : value))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
            .frame(width: 270)
        }
        .padding(.vertical, 10)
        .onDisappear {
            if editing {
                value = draft
                editing = false
            }
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider().opacity(0.55)
    }
}

private struct SettingsFooter: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 4)
=======
    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0.01,
         format: @escaping (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }) {
        self.title = title; self._value = value; self.range = range; self.step = step; self.format = format
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 12) {
                Slider(value: Binding(get: { editing ? draft : value }, set: {
                    draft = min(range.upperBound, max(range.lowerBound, ($0 / step).rounded() * step))
                    if !editing { value = draft }
                }), in: range, onEditingChanged: { active in
                    if active { draft = value; editing = true }
                    else { editing = false; value = draft }
                })
                .accessibilityLabel(title)
                Text(format(editing ? draft : value))
                    .monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }.frame(minWidth: 220, maxWidth: 310)
        }
        .onDisappear { if editing { value = draft; editing = false } }
>>>>>>> 10bb768fe8843589f7fb9f1375d2e6e8eaec9fb6
    }
}

private struct DisplaySettings: View {
<<<<<<< HEAD
    @ObservedObject var store: ConfigurationStore
    @ObservedObject var displays: DisplayManager

    var body: some View {
        SettingsGlassContainer(spacing: 18) {
            VStack(spacing: 18) {
                SettingsGroup(
                    title: "Display behaviour",
                    subtitle: "Coordinate appearance across every connected screen.",
                    icon: "rectangle.on.rectangle.angled",
                    tint: SettingsPage.displays.accent
                ) {
                    SettingsToggleRow(
                        title: "Share appearance across displays",
                        detail: "Use the same theme lighting and information settings everywhere.",
                        isOn: $store.configuration.useSameAppearanceOnAllDisplays
                    )
                    SettingsDivider()
                    HStack {
                        Text("Brightness is always remembered per display.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            displays.identifyDisplays()
                        } label: {
                            Label("Identify", systemImage: "rectangle.inset.filled.and.person.filled")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                }

                ForEach(displays.displays) { display in
                    SettingsGroup(
                        title: display.name,
                        subtitle: "\(display.resolution) · \(display.orientationName)",
                        icon: display.isPortrait ? "rectangle.portrait" : "display",
                        tint: SettingsPage.displays.accent
                    ) {
                        SettingsToggleRow(
                            title: "Show Vinyl",
                            detail: "Place the desktop turntable on this display.",
                            isOn: enabledBinding(display.id)
                        )
                        SettingsDivider()
                        SettingsSlider(
                            "Brightness",
                            detail: "Compensate for this display’s output.",
                            value: exposureBinding(display.id),
                            range: -0.20...0.40,
                            format: { String(format: "%+.0f%%", $0 * 100) }
                        )

                        if !store.configuration.useSameAppearanceOnAllDisplays {
                            SettingsDivider()
                            SettingsToggleRow(
                                title: "Platter glow",
                                detail: "Use album-reactive lighting on this display.",
                                isOn: displayAppearance(display.id, \.platterGlow)
                            )
                            SettingsDivider()
                            SettingsSlider(
                                "Glow intensity",
                                detail: "Set the lighting strength for this display.",
                                value: displayAppearance(display.id, \.lightingIntensity),
                                range: 0...1
                            )
                        }
                    }
                }

                if displays.displays.isEmpty {
                    ContentUnavailableView(
                        "No Displays Detected",
                        systemImage: "display.trianglebadge.exclamationmark",
                        description: Text("Connect a display to configure Vinyl.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(36)
                    .settingsGlass(cornerRadius: 22)
                }

                Label("Disconnected displays are remembered for next time.", systemImage: "externaldrive.badge.timemachine")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func enabledBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { store.configuration.isEnabled(displayID: id) },
            set: {
                store.ensureDisplay(id)
                store.configuration.displayConfigurations[id]?.enabled = $0
            }
        )
    }

    private func exposureBinding(_ id: String) -> Binding<Double> {
        Binding(
            get: { store.configuration.sceneExposure(for: id) },
            set: {
                store.ensureDisplay(id)
                store.configuration.displayConfigurations[id]?.sceneExposure = $0
            }
        )
    }

    private func displayAppearance<T>(
        _ id: String,
        _ keyPath: WritableKeyPath<AppearanceConfiguration, T>
    ) -> Binding<T> {
        Binding(
            get: { store.configuration.appearance(for: id)[keyPath: keyPath] },
            set: {
                store.ensureDisplay(id)
                store.configuration.displayConfigurations[id]?.appearance[keyPath: keyPath] = $0
            }
        )
    }
}

private struct SettingsGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

private extension View {
    func settingsGlass(
        cornerRadius: CGFloat,
        tint: Color = .clear,
        interactive: Bool = false
    ) -> some View {
        modifier(SettingsGlassModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

private struct SettingsGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12))
                }
        }
    }
=======
    @ObservedObject var model: AppModel
    @ObservedObject var store: ConfigurationStore
    @ObservedObject var displays: DisplayManager
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Connected displays").font(.headline); Spacer(); Button("Identify Displays") { model.displayManager.identifyDisplays() } }
            Toggle("Use same appearance on all displays", isOn: Binding(get: { store.configuration.useSameAppearanceOnAllDisplays }, set: { store.configuration.useSameAppearanceOnAllDisplays = $0 }))
            ForEach(displays.displays) { display in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Image(systemName: display.isPortrait ? "rectangle.portrait" : "display")
                        VStack(alignment: .leading) { Text(display.name).font(.headline); Text("\(display.resolution) · \(display.orientationName) · \(String(format: "%.1f×", display.scale))").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Toggle("Vinyl", isOn: enabledBinding(display.id)).toggleStyle(.switch)
                    }
                    if !store.configuration.useSameAppearanceOnAllDisplays {
                        Picker("Theme", selection: displayThemeBinding(display.id)) { ForEach(ThemeChoice.all) { Text($0.name).tag($0.id) } }.frame(maxWidth: 340)
                        if store.configuration.appearance(for: display.id).rendererTheme != .midnight {
                            Picker("Layout", selection: displayLayoutBinding(display.id)) { ForEach(LayoutMode.allCases) { Text($0.name).tag($0) } }.frame(maxWidth: 340)
                        }
                    }
                    SettingsSlider("Brightness", value: displayExposureBinding(display.id), range: -0.20...0.40, step: 0.01, format: { String(format: "%+.0f%%", $0 * 100) })
                    Text("Lifts dark material detail for this display while protecting highlights.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Disconnected display settings are retained and restored when the same display returns.").foregroundStyle(.secondary)
        }
    }
    private func enabledBinding(_ id: String) -> Binding<Bool> { Binding(get: { store.configuration.displayConfigurations[id]?.enabled ?? true }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.enabled = $0 }) }
    private func displayThemeBinding(_ id: String) -> Binding<String> { Binding(get: { store.configuration.displayConfigurations[id]?.appearance.themeChoiceID ?? store.configuration.globalAppearance.themeChoiceID }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.appearance.themeChoiceID = $0 }) }
    private func displayLayoutBinding(_ id: String) -> Binding<LayoutMode> { Binding(get: { store.configuration.displayConfigurations[id]?.appearance.layout ?? .automatic }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.appearance.layout = $0 }) }
    private func displayExposureBinding(_ id: String) -> Binding<Double> { Binding(get: { store.configuration.sceneExposure(for: id) }, set: { store.ensureDisplay(id); store.configuration.displayConfigurations[id]?.sceneExposure = $0 }) }
    private func displayExposureLabel(_ id: String) -> String { String(format: "%+.0f%%", store.configuration.sceneExposure(for: id) * 100) }
>>>>>>> 10bb768fe8843589f7fb9f1375d2e6e8eaec9fb6
}
