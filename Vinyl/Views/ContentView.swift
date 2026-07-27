import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        ZStack {
            ambientBackdrop
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    spotifySection
                    setupSection
                }
                .frame(maxWidth: 1120)
                .padding(.horizontal, 36)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 900, minHeight: 680)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: model.isSpotifyRunning)
        .animation(.easeInOut(duration: 0.35), value: model.currentItem?.id)
    }

    private var ambientBackdrop: some View {
        Color(red: 0.12, green: 0.12, blue: 0.13)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Vinyl")
                .font(.system(size: 18, weight: .regular))

            Spacer()

            if model.isSpotifyRunning {
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color(red: 0.20, green: 0.82, blue: 0.47))
                            .frame(width: 7, height: 7)
                        Text("Spotify running")
                    }
                    .font(.caption)

                    if let spotifyURL = model.currentItem?.spotifyURL {
                        Menu {
                            Link("Open in Spotify", destination: spotifyURL)
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .liquidGlass(in: Capsule())
                .transition(.opacity)
            } else {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(white: 0.35))
                        .frame(width: 7, height: 7)
                    Text("Spotify not running")
                }
                .font(.caption)
                .padding(.leading, 14)
                .padding(.trailing, 14)
                .padding(.vertical, 8)
                .liquidGlass(in: Capsule())
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var spotifySection: some View {
        if let item = model.currentItem {
            nowPlayingBar(item)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            statusView
                .transition(.opacity)
        }
    }

    private var statusView: some View {
        HStack(spacing: 14) {
            Image(systemName: model.isSpotifyRunning ? "music.note" : "arrow.up.right")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))

            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.64))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentSurface(cornerRadius: 26)
    }

    private func nowPlayingBar(_ item: PlayingItem) -> some View {
        HStack(spacing: 18) {
            currentArtwork
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .regular))
                    .lineLimit(1)
                Text(item.artist)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)

                liveProgressBar
            }

            Spacer()

            HStack(spacing: 10) {
                Label("Desktop", systemImage: "desktopcomputer")
                    .font(.callout)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.isWallpaperEnabled },
                        set: { model.setWallpaperEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(height: 44)
            .liquidGlass(in: Capsule())
        }
        .padding(18)
        .contentSurface(cornerRadius: 26)
        .overlay(alignment: .bottomLeading) {
            if let errorMessage = model.errorMessage {
                errorView(errorMessage)
                    .offset(y: 27)
            }
        }
    }

    @ViewBuilder
    private var liveProgressBar: some View {
        if let item = model.currentItem,
           let durationMs = item.durationMilliseconds,
           let progressMs = item.progressMilliseconds,
           durationMs > 0 {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let currentMs = Self.interpolatedMs(
                    progressMs: progressMs,
                    isPlaying: item.isPlaying,
                    lastUpdated: model.lastUpdated,
                    now: context.date,
                    durationMs: durationMs
                )
                let fraction = Double(currentMs) / Double(durationMs)

                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(.white.opacity(0.84))
                        .frame(maxWidth: 360)

                    HStack {
                        Text(Self.formatTime(currentMs))
                        Spacer()
                        Text(Self.formatTime(durationMs))
                    }
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(maxWidth: 360)
                }
                .padding(.top, 5)
            }
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose a setup")
                .font(.system(size: 20, weight: .regular))

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(VinylSetup.catalogue) { setup in
                    setupCard(setup)
                }
            }
        }
    }

    @ViewBuilder
    private func setupCard(_ setup: VinylSetup) -> some View {
        if setup.isAvailable {
            let isSelected = model.selectedSetupID == setup.id

            Button {
                model.selectSetup(setup)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    SetupPreview(
                        setup: setup,
                        artworkURL: model.currentItem?.artworkURL
                    )
                    .frame(height: 176)

                    HStack(spacing: 12) {
                        Text(setup.name)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    }
                    .frame(height: 58)
                    .padding(.horizontal, 17)
                }
                .background(Color.black.opacity(0.30))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            isSelected ? .white.opacity(0.78) : .white.opacity(0.11),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
                .shadow(
                    color: isSelected ? .black.opacity(0.30) : .clear,
                    radius: 22,
                    y: 10
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Selects this desktop setup")
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.42).opacity(0.23))
                .frame(height: 234)
                .overlay {
                    Text("Coming soon")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                }
        }
    }

    private var currentArtwork: some View {
        Group {
            if let url = model.currentItem?.artworkURL {
                AsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeInOut(duration: 0.5))
                ) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
    }

    private var artworkPlaceholder: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.49, blue: 0.34),
                Color(red: 0.40, green: 0.12, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "record.circle")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func errorView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.48))
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func interpolatedMs(
        progressMs: Int,
        isPlaying: Bool,
        lastUpdated: Date?,
        now: Date,
        durationMs: Int
    ) -> Int {
        guard isPlaying, let lastUpdated else { return progressMs }
        let elapsed = Int(now.timeIntervalSince(lastUpdated) * 1000)
        return min(progressMs + elapsed, durationMs)
    }

    private static func formatTime(_ milliseconds: Int) -> String {
        let totalSeconds = max(milliseconds / 1000, 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct SetupPreview: View {
    let setup: VinylSetup
    let artworkURL: URL?

    var body: some View {
        ZStack {
            previewGradient

            switch setup.id {
            case .albumCanvas:
                albumCanvas
            case .classicDeck:
                classicDeck
            case .floatingVinyl:
                floatingVinyl
            case .listeningRoom:
                listeningRoom
            case .sideA:
                sideA
            case .afterDark:
                afterDark
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
    }

    private var previewGradient: some View {
        Group {
            switch setup.id {
            case .albumCanvas:
                LinearGradient(
                    colors: [
                        Color(red: 0.29, green: 0.14, blue: 0.075),
                        Color(red: 0.17, green: 0.075, blue: 0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .classicDeck:
                LinearGradient(
                    colors: [Color(red: 0.50, green: 0.34, blue: 0.22), Color(red: 0.13, green: 0.10, blue: 0.09)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .floatingVinyl:
                LinearGradient(
                    colors: [Color(red: 0.21, green: 0.34, blue: 0.48), Color(red: 0.08, green: 0.10, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .listeningRoom:
                LinearGradient(
                    colors: [Color(red: 0.54, green: 0.25, blue: 0.20), Color(red: 0.13, green: 0.08, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .sideA:
                LinearGradient(
                    colors: [Color(red: 0.57, green: 0.50, blue: 0.31), Color(red: 0.18, green: 0.16, blue: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .afterDark:
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.13, blue: 0.42), Color(red: 0.04, green: 0.03, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var albumCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(red: 0.22, green: 0.13, blue: 0.08))
                .frame(width: 236, height: 142)
                .overlay {
                    Image("RosewoodTexture")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 236, height: 142)
                        .rotationEffect(.degrees(90))
                        .saturation(0.76)
                        .brightness(-0.08)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.81, blue: 0.77),
                            Color(red: 0.59, green: 0.58, blue: 0.54)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 204, height: 116)
                .offset(x: 4)
                .shadow(color: .black.opacity(0.28), radius: 5, y: 3)

            ZStack {
                Circle()
                    .fill(Color(white: 0.025))
                ForEach(1..<11) { ring in
                    Circle()
                        .stroke(.white.opacity(0.045), lineWidth: 0.5)
                        .padding(CGFloat(ring) * 3.9)
                }
                previewArtwork
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
            }
            .frame(width: 111, height: 111)
            .offset(x: -30)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(white: 0.075))
                .frame(width: 31, height: 108)
                .offset(x: 85)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.89, blue: 0.85),
                            Color(white: 0.40)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 4, height: 83)
                .rotationEffect(.degrees(25), anchor: .top)
                .offset(x: 66, y: 5)

            Circle()
                .fill(Color(white: 0.10))
                .frame(width: 20, height: 20)
                .offset(x: 83, y: -45)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(red: 0.82, green: 0.10, blue: 0.045))
                .frame(width: 18, height: 5)
                .offset(x: 50, y: 49)
        }
    }

    private var classicDeck: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(red: 0.40, green: 0.25, blue: 0.16))
                .frame(width: 236, height: 128)
                .shadow(color: .black.opacity(0.38), radius: 16, y: 9)

            record(size: 105, labelColor: .orange.opacity(0.8))
                .offset(x: -38)

            Capsule()
                .fill(.white.opacity(0.72))
                .frame(width: 8, height: 86)
                .rotationEffect(.degrees(24), anchor: .top)
                .offset(x: 72, y: 5)

            Circle()
                .fill(.black.opacity(0.7))
                .frame(width: 18, height: 18)
                .offset(x: 72, y: -43)
        }
    }

    private var floatingVinyl: some View {
        record(size: 142, labelColor: Color(red: 0.45, green: 0.71, blue: 0.85))
            .rotation3DEffect(.degrees(52), axis: (x: 0.35, y: 1, z: 0))
            .shadow(color: .black.opacity(0.55), radius: 24, x: 18, y: 18)
    }

    private var listeningRoom: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 22) {
                speaker
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.10))
                        .frame(width: 86, height: 76)
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 70, height: 2)
                            .offset(y: CGFloat(-index * 22 - 12))
                    }
                }
                speaker
            }
            Capsule()
                .fill(.black.opacity(0.45))
                .frame(width: 238, height: 8)
        }
        .offset(y: 10)
    }

    private var speaker: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.black.opacity(0.62))
            .frame(width: 44, height: 86)
            .overlay {
                VStack(spacing: 8) {
                    Circle()
                        .stroke(.white.opacity(0.34), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(.white.opacity(0.34), lineWidth: 2)
                        .frame(width: 27, height: 27)
                }
            }
    }

    private var sideA: some View {
        HStack(spacing: 18) {
            record(size: 122, labelColor: Color(red: 0.86, green: 0.76, blue: 0.42))
            VStack(alignment: .leading, spacing: 3) {
                Text("SIDE")
                Text("A").font(.system(size: 54, weight: .regular))
            }
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var afterDark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.9), .pink.opacity(0.46)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 218, height: 126)
                .shadow(color: .purple.opacity(0.55), radius: 14)
            record(size: 108, labelColor: .purple.opacity(0.85))
        }
    }

    private var previewArtwork: some View {
        Group {
            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
    }

    private var fallbackArtwork: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.54, blue: 0.35),
                Color(red: 0.38, green: 0.12, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.70))
        }
    }

    private func record(size: CGFloat, labelColor: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.65), .black, Color(white: 0.04)],
                        center: .center,
                        startRadius: 3,
                        endRadius: size / 2
                    )
                )
            ForEach(1..<5) { ring in
                Circle()
                    .stroke(.white.opacity(0.07), lineWidth: 1)
                    .padding(CGFloat(ring * 8))
            }
            Circle()
                .fill(labelColor)
                .frame(width: size * 0.32, height: size * 0.32)
            Circle()
                .fill(.black.opacity(0.72))
                .frame(width: size * 0.07, height: size * 0.07)
        }
        .frame(width: size, height: size)
    }
}

private extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(
                Glass.regular
                    .tint(tint)
                    .interactive(interactive),
                in: shape
            )
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
    }

    func contentSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(Color.black.opacity(0.26), in: shape)
            .background(.thinMaterial, in: shape)
            .overlay {
                shape.stroke(.white.opacity(0.05), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }
}
