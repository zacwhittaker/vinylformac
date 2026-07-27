import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    let onComplete: () -> Void

    @AppStorage(OnboardingProgress.currentStepKey) private var savedStep = 0
    @State private var licenseKey = ""
    @State private var showOnDesktop = true
    @FocusState private var licenseFieldFocused: Bool

    private let steps = OnboardingStep.allCases

    private var step: OnboardingStep {
        OnboardingStep(rawValue: min(max(savedStep, 0), steps.count - 1)) ?? .welcome
    }

    var body: some View {
        ZStack {
            OnboardingBackdrop(accent: step.tint)

            HStack(spacing: 0) {
                progressRail
                    .frame(width: 242)

                Rectangle()
                    .fill(.separator.opacity(0.34))
                    .frame(width: 1)

                VStack(spacing: 0) {
                    stepContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    navigationBar
                }
            }
            .background(.ultraThinMaterial.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            }
            .shadow(color: .black.opacity(0.28), radius: 44, y: 18)
            .padding(20)
        }
        .frame(minWidth: 860, idealWidth: 980, minHeight: 620, idealHeight: 700)
        .animation(.snappy(duration: 0.3), value: savedStep)
        .onAppear {
            showOnDesktop = model.isWallpaperEnabled
            if step == .license { licenseFieldFocused = true }
        }
        .onChange(of: savedStep) { _, _ in
            licenseFieldFocused = step == .license
        }
    }

    private var progressRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image("VinylLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Vinyl")
                        .font(.headline)
                    Text("First-time setup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 34)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(steps) { item in
                    HStack(spacing: 11) {
                        ZStack {
                            Circle()
                                .fill(progressColour(for: item).opacity(item == step ? 0.18 : 0.08))
                            if item.rawValue < step.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            } else {
                                Text("\(item.rawValue + 1)")
                                    .font(.caption2.monospacedDigit().weight(.semibold))
                            }
                        }
                        .foregroundStyle(progressColour(for: item))
                        .frame(width: 28, height: 28)

                        Text(item.railTitle)
                            .font(.callout.weight(item == step ? .semibold : .regular))
                            .foregroundStyle(item.rawValue <= step.rawValue ? .primary : .tertiary)

                        Spacer()
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        item == step ? item.tint.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityAddTraits(item == step ? .isSelected : [])
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Label("Private by design", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                Text("Playback stays on your Mac. Vinyl only asks for access when it needs it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(24)
    }

    private var stepContent: some View {
        ScrollView {
            Group {
                switch step {
                case .welcome:
                    welcomeStep
                case .license:
                    licenseStep
                case .player:
                    playerStep
                case .theme:
                    themeStep
                case .displays:
                    displaysStep
                case .ready:
                    readyStep
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.horizontal, 46)
            .padding(.vertical, 42)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            Image("VinylLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 84, height: 84)
                .shadow(color: step.tint.opacity(0.28), radius: 24)

            StepHeading(
                eyebrow: "WELCOME TO VINYL",
                title: "Your music, built into the desktop.",
                detail: "A quiet, physical turntable that follows Spotify or Apple Music across the displays you choose."
            )

            HStack(spacing: 12) {
                FeaturePill(icon: "music.note", title: "Follows playback")
                FeaturePill(icon: "display.2", title: "Made for every display")
                FeaturePill(icon: "lock.shield", title: "Local and private")
            }

            Text("Setup takes about a minute. You can change every choice later in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var licenseStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepSymbol(name: "key.horizontal.fill", tint: step.tint)
            StepHeading(
                eyebrow: "LICENSE",
                title: "Activate Vinyl.",
                detail: "Enter the license key from your purchase email. Activation is represented here now; verification will be connected before release."
            )

            VStack(alignment: .leading, spacing: 12) {
                TextField("VINYL-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .focused($licenseFieldFocused)
                    .onSubmit(advance)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(
                                licenseFieldFocused
                                    ? step.tint.opacity(0.8)
                                    : Color(nsColor: .separatorColor).opacity(0.4)
                            )
                    }
                    .accessibilityLabel("License key")

                Label("Preview only — this build does not validate, transmit, or store the key.", systemImage: "hammer.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .onboardingCard(tint: step.tint)

            HStack(spacing: 8) {
                Image(systemName: "envelope")
                Text("When activation is enabled, this screen will also include purchase recovery and offline error states.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var playerStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepSymbol(name: "waveform", tint: step.tint)
            StepHeading(
                eyebrow: "MUSIC SOURCE",
                title: "What do you listen with?",
                detail: "Vinyl follows one desktop player at a time. It reads playback locally through macOS Automation."
            )

            HStack(spacing: 14) {
                PlayerChoice(
                    name: "Spotify",
                    detail: "Desktop app",
                    symbol: "waveform.circle.fill",
                    tint: Color(red: 0.12, green: 0.78, blue: 0.38),
                    selected: model.selectedPlayer == .spotify,
                    action: { model.selectPlayer(.spotify) }
                )
                PlayerChoice(
                    name: "Apple Music",
                    detail: "Music.app",
                    symbol: "music.note",
                    tint: Color(red: 0.98, green: 0.2, blue: 0.35),
                    selected: model.selectedPlayer == .appleMusic,
                    action: { model.selectPlayer(.appleMusic) }
                )
            }

            Label(
                "Vinyl waits until setup is complete before asking macOS for Automation access.",
                systemImage: "hand.raised.fill"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var themeStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepSymbol(name: "paintpalette.fill", tint: step.tint)
            StepHeading(
                eyebrow: "THEME",
                title: "Choose the room’s character.",
                detail: "Themes change the materials and atmosphere while keeping the same carefully tuned turntable."
            )

            Button {
                model.configurationStore.configuration.globalAppearance.themeChoiceID = "turntable.midnight"
            } label: {
                HStack(spacing: 18) {
                    Image("MidnightThemeCover")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 245, height: 154)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 9) {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(step.tint)
                        Text("Midnight")
                            .font(.title2.bold())
                        Text("Dark graphite, smoked glass and album-reactive light.")
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

                    Spacer()
                }
                .padding(14)
                .contentShape(RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
            .onboardingCard(tint: step.tint, selected: true)
            .accessibilityLabel("Midnight theme, selected")

            HStack(spacing: 9) {
                ForEach(2...5, id: \.self) { number in
                    VStack(spacing: 7) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text(String(format: "%02d", number))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityLabel("Theme \(number), coming soon")
                }
            }
        }
    }

    private var displaysStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepSymbol(name: "display.2", tint: step.tint)
            StepHeading(
                eyebrow: "DISPLAYS",
                title: "Where should Vinyl live?",
                detail: "Choose the desktops that show the turntable. Brightness remains independently adjustable in Settings."
            )

            if model.displayManager.displays.isEmpty {
                Label("No displays are currently available. Vinyl will remember this step and detect them next time.", systemImage: "display.trianglebadge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .onboardingCard(tint: step.tint)
            } else {
                VStack(spacing: 10) {
                    ForEach(model.displayManager.displays) { display in
                        DisplayChoice(
                            display: display,
                            isEnabled: displayBinding(display.id),
                            tint: step.tint
                        )
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { model.configurationStore.configuration.useSameAppearanceOnAllDisplays },
                set: { model.configurationStore.configuration.useSameAppearanceOnAllDisplays = $0 }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Share appearance across displays")
                        .font(.callout.weight(.medium))
                    Text("Use Midnight and the same lighting choices everywhere.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .accessibilityLabel("Share appearance across displays")
            .padding(16)
            .onboardingCard(tint: step.tint)
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepSymbol(name: "checkmark.seal.fill", tint: step.tint)
            StepHeading(
                eyebrow: "READY",
                title: "Your turntable is ready.",
                detail: "Vinyl will settle into the menu bar and keep the desktop in sync with your music."
            )

            VStack(spacing: 0) {
                SummaryRow(icon: "waveform", title: "Music player", value: model.selectedPlayer.name)
                Divider().opacity(0.5)
                SummaryRow(icon: "moon.stars.fill", title: "Theme", value: "Midnight")
                Divider().opacity(0.5)
                SummaryRow(
                    icon: "display.2",
                    title: "Displays",
                    value: displaySummary
                )
            }
            .padding(.horizontal, 17)
            .onboardingCard(tint: step.tint)

            Toggle(isOn: $showOnDesktop) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show Vinyl on the desktop now")
                        .font(.callout.weight(.medium))
                    Text("You can hide or show it anytime from the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .accessibilityLabel("Show Vinyl on the desktop now")
            .padding(16)
            .onboardingCard(tint: step.tint)

            Label(
                "After you choose Start Vinyl, macOS may ask for permission to control \(model.selectedPlayer.name).",
                systemImage: "gearshape.2.fill"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                Button("Back", action: retreat)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
            }

            Spacer()

            Text("Step \(step.rawValue + 1) of \(steps.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)

            Button(primaryButtonTitle, action: advance)
                .buttonStyle(.borderedProminent)
                .tint(step.tint)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .frame(height: 76)
        .background(.bar.opacity(0.52))
        .overlay(alignment: .top) { Divider().opacity(0.38) }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .license: "Continue for Now"
        case .ready: "Start Vinyl"
        default: "Continue"
        }
    }

    private var displaySummary: String {
        let enabled = model.displayManager.displays.filter {
            model.configurationStore.configuration.isEnabled(displayID: $0.id)
        }.count
        if model.displayManager.displays.isEmpty { return "Detect automatically" }
        return enabled == model.displayManager.displays.count ? "All connected" : "\(enabled) selected"
    }

    private func displayBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { model.configurationStore.configuration.isEnabled(displayID: id) },
            set: { value in
                model.configurationStore.ensureDisplay(id)
                model.configurationStore.configuration.displayConfigurations[id]?.enabled = value
            }
        )
    }

    private func progressColour(for item: OnboardingStep) -> Color {
        item.rawValue <= step.rawValue ? item.tint : .secondary
    }

    private func advance() {
        if step == .ready {
            model.configurationStore.configuration.startEnabled = showOnDesktop
            model.setWallpaperEnabled(showOnDesktop, applyImmediately: false)
            onComplete()
        } else {
            savedStep = min(savedStep + 1, steps.count - 1)
        }
    }

    private func retreat() {
        savedStep = max(savedStep - 1, 0)
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, license, player, theme, displays, ready

    var id: Int { rawValue }

    var railTitle: String {
        switch self {
        case .welcome: "Welcome"
        case .license: "License"
        case .player: "Music player"
        case .theme: "Theme"
        case .displays: "Displays"
        case .ready: "Finish"
        }
    }

    var tint: Color {
        switch self {
        case .welcome: Color(red: 0.94, green: 0.25, blue: 0.33)
        case .license: Color(red: 0.95, green: 0.54, blue: 0.22)
        case .player: Color(red: 0.32, green: 0.67, blue: 0.98)
        case .theme: Color(red: 0.66, green: 0.44, blue: 0.98)
        case .displays: Color(red: 0.24, green: 0.76, blue: 0.72)
        case .ready: Color(red: 0.27, green: 0.76, blue: 0.48)
        }
    }
}

private struct OnboardingBackdrop: View {
    let accent: Color
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
                        .blur(radius: 72)
                        .scaleEffect(1.2)
                        .saturation(0.66)
                        .opacity(0.3)

                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: min(proxy.size.width, proxy.size.height) * 0.78)
                        .blur(radius: 120)
                        .offset(x: proxy.size.width * 0.32, y: -proxy.size.height * 0.3)
                }

                LinearGradient(
                    colors: [.black.opacity(0.1), .black.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipped()
        }
        .ignoresSafeArea()
    }
}

private struct StepHeading: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(detail)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }
}

private struct StepSymbol: View {
    let name: String
    let tint: Color

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 56, height: 56)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct FeaturePill: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.primary.opacity(0.055), in: Capsule())
    }
}

private struct PlayerChoice: View {
    let name: String
    let detail: String
    let symbol: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? tint : Color.secondary.opacity(0.55))
                }
                Text(name)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .onboardingCard(tint: tint, selected: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct DisplayChoice: View {
    let display: DisplayInfo
    @Binding var isEnabled: Bool
    let tint: Color

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 13) {
                Image(systemName: display.isPortrait ? "rectangle.portrait" : "display")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(display.name)
                        .font(.callout.weight(.semibold))
                    Text("\(display.resolution) · \(display.orientationName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .accessibilityLabel("Show Vinyl on \(display.name)")
        .accessibilityValue(isEnabled ? "On" : "Off")
        .padding(14)
        .onboardingCard(tint: tint, selected: isEnabled)
    }
}

private struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
    }
}

private struct OnboardingCardModifier: ViewModifier {
    let tint: Color
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(.primary.opacity(selected ? 0.065 : 0.04), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        selected ? tint.opacity(0.48) : Color(nsColor: .separatorColor).opacity(0.25),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
    }
}

private extension View {
    func onboardingCard(tint: Color, selected: Bool = false) -> some View {
        modifier(OnboardingCardModifier(tint: tint, selected: selected))
    }
}
