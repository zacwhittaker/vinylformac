import SwiftUI

// MARK: - Global light rig
//
// Every highlight, gradient, and shadow in the scene derives from this single
// key light so the composition reads as one photographed moment instead of a
// collection of independently shaded shapes.

enum SceneLight {
    /// Unit vector pointing from a surface toward the key light
    /// (screen coordinates, y grows downward). Warm lamp, upper left.
    static let direction = CGVector(dx: -0.5547, dy: -0.8321)

    /// Offset for a shadow cast by an object `distance` above the surface
    /// beneath it: opposite the light direction.
    static func shadowOffset(_ distance: CGFloat) -> CGSize {
        CGSize(width: -direction.dx * distance, height: -direction.dy * distance)
    }

    static var shaderDirection: Shader.Argument {
        .float2(direction.dx, direction.dy)
    }
}

// MARK: - Scene

struct AlbumCanvasWallpaperView: View {
    let item: PlayingItem
    let snapshotDate: Date

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = min(h, w / 1.55)
            let deckH = unit * 0.64
            let deckW = deckH * 1.32
            let deckCenter = CGPoint(x: w * 0.655, y: h * 0.515)
            let sleeveSide = deckH * 0.82
            let sleeveCenter = CGPoint(
                x: deckCenter.x - deckW / 2 - sleeveSide * 0.50,
                y: h * 0.555
            )

            ZStack {
                TableSurface()

                FlatSleeve(artworkURL: item.artworkURL)
                    .frame(width: sleeveSide, height: sleeveSide)
                    .rotationEffect(.degrees(-3.6))
                    .position(sleeveCenter)

                TurntableDeck(item: item, snapshotDate: snapshotDate)
                    .frame(width: deckW, height: deckH)
                    .rotationEffect(.degrees(-0.35))
                    .position(deckCenter)

                // One lamp lights the whole tabletop: a warm wash that falls
                // across deck, sleeve, and wood together.
                RadialGradient(
                    stops: [
                        .init(color: Color(red: 1.0, green: 0.86, blue: 0.64).opacity(0.10), location: 0),
                        .init(color: Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.035), location: 0.5),
                        .init(color: .clear, location: 0.9)
                    ],
                    center: UnitPoint(x: 0.18, y: 0.18),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.95
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

                // Photographic finish: warmth, vignette, grain.
                Color(red: 1.0, green: 0.84, blue: 0.62)
                    .opacity(0.06)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.42)],
                    center: UnitPoint(x: 0.48, y: 0.44),
                    startRadius: min(w, h) * 0.34,
                    endRadius: max(w, h) * 0.80
                )
                .allowsHitTesting(false)

                SurfaceGrain(intensity: 0.07, seed: 11)
                    .allowsHitTesting(false)

            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Table

private struct TableSurface: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Color(red: 0.13, green: 0.09, blue: 0.06)

                Image("WalnutTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .saturation(0.88)
                    .contrast(1.03)
                    .brightness(-0.05)
                    .blur(radius: 0.5)

                Image("WalnutRoughness")
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .contrast(1.25)
                    .opacity(0.10)
                    .blendMode(.softLight)

                // Warm pool where the key light lands.
                RadialGradient(
                    stops: [
                        .init(color: Color(red: 1.0, green: 0.80, blue: 0.52).opacity(0.12), location: 0),
                        .init(color: Color(red: 1.0, green: 0.85, blue: 0.62).opacity(0.04), location: 0.42),
                        .init(color: .clear, location: 0.82)
                    ],
                    center: UnitPoint(x: 0.18, y: 0.22),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.80
                )
                .blendMode(.screen)

                // Soft diagonal band of window light across the table.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .white.opacity(0.032), location: 0.22),
                        .init(color: .clear, location: 0.46),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)

                // Ambient falloff away from the light: the far corner sinks.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.36),
                        .init(color: .black.opacity(0.38), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // A table that gets lived on: sparse scratches and an old
                // mug ring off to the side.
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    for scratch in 0..<18 {
                        let x = materialNoise(scratch, salt: 0.31) * size.width
                        let y = materialNoise(scratch, salt: 1.17) * size.height
                        let length = 10 + materialNoise(scratch, salt: 2.03) * 100
                        let slope = (materialNoise(scratch, salt: 2.89) - 0.5) * 5
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y + slope))
                        context.stroke(
                            path,
                            with: .color(
                                scratch.isMultiple(of: 4)
                                    ? .black.opacity(0.11)
                                    : .white.opacity(0.055)
                            ),
                            lineWidth: scratch.isMultiple(of: 4) ? 0.7 : 0.4
                        )
                    }

                    let ring = CGRect(
                        x: size.width * 0.105,
                        y: size.height * 0.775,
                        width: size.height * 0.085,
                        height: size.height * 0.082
                    )
                    context.stroke(
                        Path(ellipseIn: ring),
                        with: .color(.black.opacity(0.10)),
                        lineWidth: size.height * 0.007
                    )
                }
                .blur(radius: 1.2)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }
}

// MARK: - Album sleeve, flat on the table

private struct FlatSleeve: View {
    let artworkURL: URL?

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            let corner = s * 0.010
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack {
                // Grounding shadows: wide ambient plus tight contact.
                shape
                    .fill(.black.opacity(0.34))
                    .offset(SceneLight.shadowOffset(s * 0.026))
                    .blur(radius: s * 0.022)
                shape
                    .fill(.black.opacity(0.52))
                    .offset(SceneLight.shadowOffset(s * 0.005))
                    .blur(radius: s * 0.004)

                // Inner paper sleeve peeking from the open edge.
                RoundedRectangle(cornerRadius: corner * 0.8, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.915, blue: 0.875))
                    .frame(width: s * 0.985, height: s * 0.955)
                    .rotationEffect(.degrees(1.1))
                    .offset(x: s * 0.043)
                    .shadow(color: .black.opacity(0.32), radius: s * 0.006,
                            x: SceneLight.shadowOffset(s * 0.006).width,
                            y: SceneLight.shadowOffset(s * 0.006).height)

                // Cardboard jacket with the artwork printed full bleed.
                ZStack {
                    shape.fill(Color(red: 0.90, green: 0.88, blue: 0.84))

                    WallpaperArtwork(url: artworkURL)
                        .frame(width: s, height: s)
                        .saturation(0.92)
                        .contrast(0.965)
                        .brightness(-0.025)

                    // Ring wear from the record inside.
                    Circle()
                        .stroke(.white.opacity(0.075), lineWidth: s * 0.05)
                        .frame(width: s * 0.85, height: s * 0.85)
                        .blur(radius: s * 0.024)

                    // Old crease across the bottom-right corner.
                    Path { path in
                        path.move(to: CGPoint(x: s * 0.78, y: s * 1.0))
                        path.addLine(to: CGPoint(x: s * 1.0, y: s * 0.80))
                    }
                    .stroke(.white.opacity(0.10), lineWidth: s * 0.004)
                    Path { path in
                        path.move(to: CGPoint(x: s * 0.782, y: s * 1.0))
                        path.addLine(to: CGPoint(x: s * 1.0, y: s * 0.802))
                    }
                    .stroke(.black.opacity(0.08), lineWidth: s * 0.003)

                    // Worn edges, corner dings.
                    shape
                        .stroke(.white.opacity(0.09), lineWidth: s * 0.006)
                        .blur(radius: 1)

                    SleeveWear()

                    // Spine crease along the closed left edge.
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.black.opacity(0.15))
                            .frame(width: s * 0.007)
                        Rectangle()
                            .fill(.white.opacity(0.09))
                            .frame(width: s * 0.005)
                        Spacer()
                    }

                    // Matte print sheen, aligned with the key light.
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.15), location: 0),
                            .init(color: .clear, location: 0.30),
                            .init(color: .clear, location: 0.70),
                            .init(color: .black.opacity(0.15), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    SurfaceGrain(intensity: 0.11, seed: 3)

                    MaterialImperfections(scratchesOpacity: 0.05, dustOpacity: 0.09)
                }
                .compositingGroup()
                .clipShape(shape)

                // Cardboard thickness on the edges turned away from the light.
                shape
                    .stroke(.black.opacity(0.32), lineWidth: s * 0.004)
                    .offset(SceneLight.shadowOffset(s * 0.003))
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
}

/// Scuffed corners and tiny dings — cardboard never stays perfect.
private struct SleeveWear: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)

            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, _ in
                // Whitened corners where the print rubbed off.
                let corners = [
                    CGPoint(x: s * 0.015, y: s * 0.015),
                    CGPoint(x: s * 0.985, y: s * 0.985),
                    CGPoint(x: s * 0.985, y: s * 0.02)
                ]
                for (i, corner) in corners.enumerated() {
                    let reach = s * (0.018 + materialNoise(i, salt: 31.7) * 0.02)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: corner.x - reach, y: corner.y - reach,
                            width: reach * 2, height: reach * 2
                        )),
                        with: .color(.white.opacity(0.16))
                    )
                }

                // Small edge nicks.
                for nick in 0..<10 {
                    let edge = nick % 4
                    let t = materialNoise(nick, salt: 13.7)
                    let len = s * (0.004 + materialNoise(nick, salt: 14.4) * 0.010)
                    var path = Path()
                    switch edge {
                    case 0:
                        path.move(to: CGPoint(x: t * s, y: s * 0.004))
                        path.addLine(to: CGPoint(x: t * s + len, y: s * 0.006))
                    case 1:
                        path.move(to: CGPoint(x: s * 0.996, y: t * s))
                        path.addLine(to: CGPoint(x: s * 0.994, y: t * s + len))
                    case 2:
                        path.move(to: CGPoint(x: t * s, y: s * 0.996))
                        path.addLine(to: CGPoint(x: t * s + len, y: s * 0.994))
                    default:
                        path.move(to: CGPoint(x: s * 0.004, y: t * s))
                        path.addLine(to: CGPoint(x: s * 0.006, y: t * s + len))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.30)), lineWidth: 0.9)
                }
            }
            .blur(radius: 0.4)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Turntable

private struct TurntableDeck: View {
    let item: PlayingItem
    let snapshotDate: Date

    var body: some View {
        GeometryReader { proxy in
            let W = proxy.size.width
            let H = proxy.size.height
            let corner = H * 0.040
            let platterD = H * 0.86
            let platterCenter = CGPoint(x: W * 0.370, y: H * 0.500)
            let recordD = platterD * 0.965
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack {
                // Grounding shadows.
                shape
                    .fill(.black.opacity(0.34))
                    .offset(SceneLight.shadowOffset(H * 0.032))
                    .blur(radius: H * 0.026)
                shape
                    .fill(.black.opacity(0.46))
                    .offset(SceneLight.shadowOffset(H * 0.008))
                    .blur(radius: H * 0.006)

                // Chassis side, visible where the body turns away from the light.
                shape
                    .fill(Color(red: 0.38, green: 0.37, blue: 0.355))
                    .offset(SceneLight.shadowOffset(H * 0.012))

                DeckFace(corner: corner)

                // Recess where the platter sits.
                Circle()
                    .stroke(.black.opacity(0.38), lineWidth: platterD * 0.018)
                    .frame(width: platterD * 1.016, height: platterD * 1.016)
                    .position(platterCenter)
                    .blur(radius: platterD * 0.007)

                Platter()
                    .frame(width: platterD, height: platterD)
                    .position(platterCenter)

                // The record throws its own shadow onto the platter rim.
                Circle()
                    .fill(.black.opacity(0.38))
                    .frame(width: recordD, height: recordD)
                    .offset(SceneLight.shadowOffset(recordD * 0.007))
                    .blur(radius: recordD * 0.005)
                    .position(platterCenter)

                RecordAssembly(item: item, snapshotDate: snapshotDate)
                    .frame(width: recordD, height: recordD)
                    .position(platterCenter)

                ControlCluster()

                TonearmAssembly(
                    recordCenter: platterCenter,
                    recordDiameter: recordD
                )

                DeckDetails(corner: corner)
            }
        }
    }
}

private struct DeckFace: View {
    let corner: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack {
                // Aged champagne aluminum, clearly brighter toward the key
                // light and slightly warmer than a new silver appliance.
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.885, green: 0.855, blue: 0.790), location: 0),
                            .init(color: Color(red: 0.790, green: 0.758, blue: 0.695), location: 0.38),
                            .init(color: Color(red: 0.665, green: 0.635, blue: 0.575), location: 0.74),
                            .init(color: Color(red: 0.565, green: 0.540, blue: 0.492), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                Rectangle()
                    .fill(.gray)
                    .colorEffect(
                        ShaderLibrary.brushedMetal(
                            .float2(proxy.size.width, proxy.size.height),
                            .float(7)
                        )
                    )
                    .blendMode(.softLight)

                // Bloom where the lamp hits the face.
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.92, blue: 0.78).opacity(0.24),
                        .clear
                    ],
                    center: UnitPoint(x: 0.12, y: 0.06),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.60
                )
                .blendMode(.screen)

                // Occlusion creeping in along the far edges.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.55),
                        .init(color: .black.opacity(0.14), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                MaterialImperfections(scratchesOpacity: 0.050, dustOpacity: 0.035)

                DeckPatina()

                SurfaceGrain(intensity: 0.05, seed: 5)

                // Machined edge: bright where it faces the light, dark opposite.
                shape
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .black.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                shape
                    .inset(by: 1.5)
                    .stroke(.black.opacity(0.12), lineWidth: 1)
                    .blur(radius: 0.8)
            }
            .compositingGroup()
            .clipShape(shape)
        }
    }
}

/// Age on the aluminum: faint discoloration blotches and use scuffs around
/// the controls.
private struct DeckPatina: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                ForEach(0..<6, id: \.self) { mark in
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .black.opacity(mark.isMultiple(of: 2) ? 0.06 : 0.035),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: w * 0.05
                            )
                        )
                        .frame(
                            width: w * (0.04 + materialNoise(mark, salt: 21.4) * 0.09),
                            height: h * (0.02 + materialNoise(mark, salt: 22.8) * 0.05)
                        )
                        .position(
                            x: w * (0.05 + materialNoise(mark, salt: 23.6) * 0.9),
                            y: h * (0.05 + materialNoise(mark, salt: 24.7) * 0.9)
                        )
                        .blur(radius: 3)
                }

                // Fingerprint smudges where the deck gets handled.
                ForEach(0..<3, id: \.self) { print in
                    Ellipse()
                        .fill(.black.opacity(0.030))
                        .frame(
                            width: w * (0.030 + materialNoise(print, salt: 61.3) * 0.020),
                            height: h * (0.030 + materialNoise(print, salt: 62.1) * 0.028)
                        )
                        .rotationEffect(.degrees(Double(materialNoise(print, salt: 63.4)) * 80 - 40))
                        .position(
                            x: w * [0.80, 0.86, 0.075][print],
                            y: h * [0.60, 0.88, 0.14][print]
                        )
                        .blur(radius: 2.5)
                }

                // Scuffing where hands reach the controls.
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    for scuff in 0..<8 {
                        let cx = size.width * (0.78 + materialNoise(scuff, salt: 41.2) * 0.18)
                        let cy = size.height * (0.55 + materialNoise(scuff, salt: 42.8) * 0.38)
                        let r = size.height * (0.02 + materialNoise(scuff, salt: 43.5) * 0.05)
                        let start = Double(materialNoise(scuff, salt: 44.1)) * 320
                        var path = Path()
                        path.addArc(
                            center: CGPoint(x: cx, y: cy),
                            radius: r,
                            startAngle: .degrees(start),
                            endAngle: .degrees(start + 40 + Double(materialNoise(scuff, salt: 45.7)) * 60),
                            clockwise: false
                        )
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.06)),
                            lineWidth: 0.6
                        )
                    }

                    // Small perimeter nicks break the perfectly manufactured
                    // silhouette without making the deck look neglected.
                    for nick in 0..<18 {
                        let side = nick % 4
                        let position = materialNoise(nick, salt: 71.6)
                        let length = 1.0 + materialNoise(nick, salt: 72.8) * 4.0
                        var path = Path()

                        switch side {
                        case 0:
                            let x = size.width * position
                            path.move(to: CGPoint(x: x, y: 1.2))
                            path.addLine(to: CGPoint(x: x + length, y: 2.0))
                        case 1:
                            let y = size.height * position
                            path.move(to: CGPoint(x: size.width - 1.2, y: y))
                            path.addLine(to: CGPoint(x: size.width - 2.0, y: y + length))
                        case 2:
                            let x = size.width * position
                            path.move(to: CGPoint(x: x, y: size.height - 1.2))
                            path.addLine(to: CGPoint(x: x + length, y: size.height - 2.0))
                        default:
                            let y = size.height * position
                            path.move(to: CGPoint(x: 1.2, y: y))
                            path.addLine(to: CGPoint(x: 2.0, y: y + length))
                        }

                        context.stroke(
                            path,
                            with: .color(
                                nick.isMultiple(of: 3)
                                    ? .black.opacity(0.20)
                                    : .white.opacity(0.20)
                            ),
                            lineWidth: 0.65
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Platter: View {
    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.black)
                .colorEffect(
                    ShaderLibrary.platterSurface(
                        .float2(proxy.size.width, proxy.size.height),
                        SceneLight.shaderDirection
                    )
                )
        }
    }
}

private struct RecordAssembly: View {
    let item: PlayingItem
    let snapshotDate: Date

    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            let labelD = d * 0.315

            ZStack {
                // Static vinyl surface: grooves are rotationally symmetric, so
                // only the label, dust, and smudges need to spin.
                Rectangle()
                    .fill(.black)
                    .colorEffect(
                        ShaderLibrary.vinylSurface(
                            .float2(d, d),
                            SceneLight.shaderDirection
                        )
                    )

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !item.isPlaying)) { context in
                    ZStack {
                        RecordDust()
                            .frame(width: d * 0.96, height: d * 0.96)

                        // Pressing is never dead-centre; the label wobbles a
                        // hair as the record turns.
                        RecordLabel(artworkURL: item.artworkURL)
                            .frame(width: labelD, height: labelD)
                            .offset(x: d * 0.0035, y: d * 0.0015)
                    }
                    .rotationEffect(rotation(at: context.date))
                }

                Spindle()
                    .frame(width: d * 0.022, height: d * 0.022)
            }
            .frame(width: d, height: d)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func rotation(at date: Date) -> Angle {
        let snapshotProgress = Double(item.progressMilliseconds ?? 0) / 1_000
        let elapsed = item.isPlaying ? max(0, date.timeIntervalSince(snapshotDate)) : 0
        return .degrees((snapshotProgress + elapsed) * 30)
    }
}

private struct RecordDust: View {
    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)

            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for dust in 0..<22 {
                    let angle = materialNoise(dust, salt: 8.1) * .pi * 2
                    let radius = size.width * (0.20 + materialNoise(dust, salt: 9.2) * 0.27)
                    let x = center.x + cos(angle) * radius
                    let y = center.y + sin(angle) * radius
                    let speck = CGRect(
                        x: x, y: y,
                        width: 0.4 + materialNoise(dust, salt: 10.2) * 1.0,
                        height: 0.25 + materialNoise(dust, salt: 11.3) * 0.55
                    )
                    context.fill(
                        Path(ellipseIn: speck),
                        with: .color(.white.opacity(0.025 + Double(materialNoise(dust, salt: 12.2)) * 0.065))
                    )
                }

                // Faint handling smudges: soft arc bands where fingers held
                // the record.
                for smudge in 0..<3 {
                    let radius = size.width * (0.30 + materialNoise(smudge, salt: 51.3) * 0.16)
                    let start = Double(materialNoise(smudge, salt: 52.9)) * 360
                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(start),
                        endAngle: .degrees(start + 16 + Double(materialNoise(smudge, salt: 53.7)) * 24),
                        clockwise: false
                    )
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.028)),
                        lineWidth: d * 0.035
                    )
                }
            }
            .blur(radius: 0.6)
        }
    }
}

private struct RecordLabel: View {
    let artworkURL: URL?

    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)

            ZStack {
                // Matte paper label.
                WallpaperArtwork(url: artworkURL)
                    .frame(width: d, height: d)
                    .saturation(0.94)
                    .contrast(0.96)
                    .brightness(-0.03)
                    .clipShape(Circle())

                SurfaceGrain(intensity: 0.13, seed: 9)
                    .clipShape(Circle())

                // Pressing ridges embossed into the paper.
                ForEach([0.90, 0.62], id: \.self) { inset in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .black.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(0.6, d * 0.006)
                        )
                        .frame(width: d * inset, height: d * inset)
                        .opacity(0.7)
                }

                // Slight shadow where vinyl meets the paper.
                Circle()
                    .stroke(.black.opacity(0.40), lineWidth: max(0.8, d * 0.010))
                    .blur(radius: 0.6)
            }
            .compositingGroup()
            .frame(width: d, height: d)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct Spindle: View {
    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(.black.opacity(0.5))
                    .frame(width: d * 1.5, height: d * 1.5)
                    .offset(SceneLight.shadowOffset(d * 0.18))
                    .blur(radius: d * 0.15)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.98), Color(white: 0.42)],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: d
                        )
                    )
                Circle()
                    .stroke(.black.opacity(0.45), lineWidth: 0.6)
            }
            .frame(width: d, height: d)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

// MARK: - Tonearm

private struct TonearmAssembly: View {
    let recordCenter: CGPoint
    let recordDiameter: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let H = proxy.size.height
            let W = proxy.size.width
            let pivot = CGPoint(x: W * 0.858, y: H * 0.215)
            let recordR = recordDiameter / 2

            // Stylus rests two-thirds into the grooves, lower right of the disc.
            let stylusRad = Angle.degrees(68).radians
            let stylus = CGPoint(
                x: recordCenter.x + CGFloat(cos(stylusRad)) * recordR * 0.72,
                y: recordCenter.y + CGFloat(sin(stylusRad)) * recordR * 0.72
            )

            let armVector = CGVector(dx: stylus.x - pivot.x, dy: stylus.y - pivot.y)
            let armLength = sqrt(armVector.dx * armVector.dx + armVector.dy * armVector.dy)
            let armUnit = CGVector(dx: armVector.dx / armLength, dy: armVector.dy / armLength)
            let armAngle = Angle.radians(atan2(Double(armVector.dy), Double(armVector.dx)))

            let headshellLength = H * 0.100
            // Tube dives into the back of the headshell so the joint reads as
            // one machine, not two shapes butted together.
            let tubeEnd = CGPoint(
                x: stylus.x - armUnit.dx * headshellLength * 0.45,
                y: stylus.y - armUnit.dy * headshellLength * 0.45
            )
            let collar = CGPoint(
                x: stylus.x - armUnit.dx * headshellLength * 0.88,
                y: stylus.y - armUnit.dy * headshellLength * 0.88
            )
            let counterweightCenter = CGPoint(
                x: pivot.x - armUnit.dx * H * 0.108,
                y: pivot.y - armUnit.dy * H * 0.108
            )

            let tube = Path { path in
                path.move(to: pivot)
                path.addLine(to: tubeEnd)
            }
            // Stub that carries the counterweight behind the pivot.
            let stub = Path { path in
                path.move(to: pivot)
                path.addLine(to: CGPoint(
                    x: pivot.x - armUnit.dx * H * 0.13,
                    y: pivot.y - armUnit.dy * H * 0.13
                ))
            }

            ZStack {
                // Two-level shadow: the arm floats well above the record, so it
                // throws a soft displaced shadow plus a fainter wide one.
                Path { path in
                    path.move(to: pivot)
                    path.addLine(to: stylus)
                }
                .stroke(
                    .black.opacity(0.20),
                    style: StrokeStyle(lineWidth: H * 0.022, lineCap: .round)
                )
                .offset(SceneLight.shadowOffset(H * 0.030))
                .blur(radius: H * 0.014)

                Path { path in
                    path.move(to: pivot)
                    path.addLine(to: stylus)
                }
                .stroke(
                    .black.opacity(0.26),
                    style: StrokeStyle(lineWidth: H * 0.012, lineCap: .round)
                )
                .offset(SceneLight.shadowOffset(H * 0.013))
                .blur(radius: H * 0.006)

                // Rear stub the counterweight rides on.
                stub
                    .stroke(
                        .black.opacity(0.35),
                        style: StrokeStyle(lineWidth: H * 0.0145, lineCap: .round)
                    )
                    .offset(
                        x: -SceneLight.direction.dx * H * 0.002,
                        y: -SceneLight.direction.dy * H * 0.002
                    )
                stub
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.70), Color(white: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: H * 0.0115, lineCap: .round)
                    )

                // Counterweight: a lying cylinder. Its cast shadow is drawn
                // separately (rotated with the body but offset in scene space)
                // so the weight clearly floats above the face.
                RoundedRectangle(cornerRadius: H * 0.012, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .frame(width: H * 0.062, height: H * 0.044)
                    .rotationEffect(armAngle)
                    .position(counterweightCenter)
                    .offset(SceneLight.shadowOffset(H * 0.011))
                    .blur(radius: H * 0.006)

                ZStack {
                    // Cross-axis cylinder shading: the local +y edge faces the
                    // lamp for this arm geometry.
                    RoundedRectangle(cornerRadius: H * 0.010, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(white: 0.14), location: 0),
                                    .init(color: Color(white: 0.38), location: 0.30),
                                    .init(color: Color(white: 0.82), location: 0.68),
                                    .init(color: Color(white: 0.55), location: 0.92),
                                    .init(color: Color(white: 0.30), location: 1)
                                ],
                                startPoint: UnitPoint(x: 0.5, y: 0),
                                endPoint: UnitPoint(x: 0.5, y: 1)
                            )
                        )
                    // Specular streak running the length of the barrel.
                    Capsule()
                        .fill(.white.opacity(0.55))
                        .frame(width: H * 0.048, height: H * 0.0035)
                        .offset(y: H * 0.0095)
                        .blur(radius: 0.4)
                    // Knurling.
                    HStack(spacing: H * 0.0065) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(.black.opacity(0.30))
                                .frame(width: H * 0.0025)
                        }
                    }
                    // End caps read as machined edges.
                    HStack {
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(width: H * 0.0022)
                        Spacer()
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(width: H * 0.0022)
                    }
                    RoundedRectangle(cornerRadius: H * 0.010, style: .continuous)
                        .stroke(.black.opacity(0.30), lineWidth: 0.6)
                }
                .frame(width: H * 0.062, height: H * 0.046)
                .rotationEffect(armAngle)
                .position(counterweightCenter)

                // Chrome tube: dark underside, bright core, specular hairline.
                tube
                    .stroke(
                        .black.opacity(0.40),
                        style: StrokeStyle(lineWidth: H * 0.0170, lineCap: .round)
                    )
                    .offset(
                        x: -SceneLight.direction.dx * H * 0.0022,
                        y: -SceneLight.direction.dy * H * 0.0022
                    )
                tube
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.90, green: 0.89, blue: 0.87),
                                Color(white: 0.52)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: H * 0.0130, lineCap: .round)
                    )
                tube
                    .stroke(
                        .white.opacity(0.85),
                        style: StrokeStyle(lineWidth: H * 0.0034, lineCap: .round)
                    )
                    .offset(
                        x: SceneLight.direction.dx * H * 0.0030,
                        y: SceneLight.direction.dy * H * 0.0030
                    )

                Headshell(
                    length: headshellLength,
                    height: H * 0.048,
                    angle: armAngle
                )
                .position(
                    x: stylus.x - armUnit.dx * headshellLength * 0.35,
                    y: stylus.y - armUnit.dy * headshellLength * 0.35
                )
                .shadow(
                    color: .black.opacity(0.42),
                    radius: H * 0.005,
                    x: SceneLight.shadowOffset(H * 0.009).width,
                    y: SceneLight.shadowOffset(H * 0.009).height
                )

                // Locking collar where tube meets headshell.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.80), Color(white: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule().stroke(.black.opacity(0.35), lineWidth: 0.5)
                    )
                    .frame(width: H * 0.016, height: H * 0.030)
                    .rotationEffect(armAngle)
                    .position(collar)

                // Pivot bearing: a raised cylinder stack. Each level throws a
                // contact shadow on the one below and shows a sliver of side
                // wall — dark away from the lamp, bright toward it — which is
                // what actually sells the height from straight above.
                PivotTower(height: H)
                    .position(pivot)

                // Tight contact shadow where the stylus meets the groove.
                Ellipse()
                    .fill(.black.opacity(0.5))
                    .frame(width: H * 0.022, height: H * 0.012)
                    .blur(radius: 1.4)
                    .position(
                        x: stylus.x + SceneLight.shadowOffset(H * 0.004).width,
                        y: stylus.y + SceneLight.shadowOffset(H * 0.004).height
                    )
            }
        }
    }
}

/// The visible side wall of a raised cylinder seen from straight above:
/// a bright crescent facing the lamp, a dark crescent away from it.
private struct CylinderRim: View {
    var lineWidth: CGFloat
    var brightness: Double = 0.55
    var darkness: Double = 0.40

    var body: some View {
        // Key light sits at 236° in gradient space (angle 0 at 3 o'clock,
        // clockwise, y down): 236/360 ≈ 0.656.
        Circle()
            .strokeBorder(
                AngularGradient(
                    stops: [
                        .init(color: .black.opacity(darkness * 0.55), location: 0),
                        .init(color: .black.opacity(darkness), location: 0.156),
                        .init(color: .black.opacity(darkness * 0.30), location: 0.40),
                        .init(color: .white.opacity(brightness), location: 0.656),
                        .init(color: .black.opacity(darkness * 0.30), location: 0.90),
                        .init(color: .black.opacity(darkness * 0.55), location: 1)
                    ],
                    center: .center
                ),
                lineWidth: lineWidth
            )
    }
}

/// The tonearm's pivot bearing as a stack of machined cylinders, with the
/// inter-level contact shadows and side walls that make it read as raised
/// hardware instead of printed rings.
private struct PivotTower: View {
    let height: CGFloat

    var body: some View {
        let H = height
        let flangeD = H * 0.105
        let ringD = H * 0.070
        let capD = H * 0.040

        ZStack {
            // Whole tower throws one soft shadow onto the deck face.
            Circle()
                .fill(.black.opacity(0.30))
                .frame(width: flangeD * 0.98, height: flangeD * 0.98)
                .offset(SceneLight.shadowOffset(H * 0.013))
                .blur(radius: H * 0.009)

            // Base flange.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.81, blue: 0.785),
                            Color(red: 0.575, green: 0.565, blue: 0.545)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: flangeD, height: flangeD)
            CylinderRim(lineWidth: flangeD * 0.035, brightness: 0.5, darkness: 0.38)
                .frame(width: flangeD, height: flangeD)

            // The ring level presses a contact shadow into the flange.
            Circle()
                .fill(.black.opacity(0.32))
                .frame(width: ringD * 1.10, height: ringD * 1.10)
                .offset(SceneLight.shadowOffset(H * 0.007))
                .blur(radius: H * 0.005)

            // Machined outer ring, clearly taller than the flange.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.88),
                            Color(white: 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: ringD, height: ringD)
            CylinderRim(lineWidth: ringD * 0.09, brightness: 0.65, darkness: 0.5)
                .frame(width: ringD, height: ringD)

            // Bearing gap between ring and cap.
            Circle()
                .stroke(.black.opacity(0.55), lineWidth: H * 0.0035)
                .frame(width: capD * 1.16, height: capD * 1.16)

            // Cap's own contact shadow inside the ring.
            Circle()
                .fill(.black.opacity(0.30))
                .frame(width: capD * 1.06, height: capD * 1.06)
                .offset(SceneLight.shadowOffset(H * 0.004))
                .blur(radius: H * 0.003)

            // Domed centre cap: hot spot toward the lamp, falling away to a
            // dark far rim.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(white: 0.96), location: 0),
                            .init(color: Color(white: 0.72), location: 0.30),
                            .init(color: Color(white: 0.42), location: 0.66),
                            .init(color: Color(white: 0.20), location: 1)
                        ],
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 0,
                        endRadius: capD * 0.85
                    )
                )
                .frame(width: capD, height: capD)
            // Occlusion where the dome meets its seat.
            Circle()
                .strokeBorder(.black.opacity(0.28), lineWidth: capD * 0.09)
                .frame(width: capD, height: capD)
                .blur(radius: 0.5)
            // Pin-sharp glint.
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: capD * 0.14, height: capD * 0.14)
                .offset(
                    x: SceneLight.direction.dx * capD * 0.24,
                    y: SceneLight.direction.dy * capD * 0.24
                )
                .blur(radius: 0.3)
        }
    }
}

/// Tapered headshell with cartridge, drawn in its own local frame and dropped
/// onto the arm axis.
private struct Headshell: View {
    let length: CGFloat
    let height: CGFloat
    let angle: Angle

    var body: some View {
        ZStack {
            // Tapered body: wider at the collar, slimmer at the cartridge.
            HeadshellShape()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.32), Color(white: 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            HeadshellShape()
                .stroke(.white.opacity(0.20), lineWidth: 0.6)

            // Cartridge block near the front.
            RoundedRectangle(cornerRadius: height * 0.10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.22), Color(white: 0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: length * 0.28, height: height * 0.78)
                .offset(x: length * 0.28)

            // Red stylus assembly poking out of the front.
            RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                .fill(Color(red: 0.62, green: 0.11, blue: 0.08))
                .frame(width: length * 0.085, height: height * 0.30)
                .offset(x: length * 0.43, y: height * 0.16)
        }
        .frame(width: length, height: height)
        .rotationEffect(angle)
    }
}

private struct HeadshellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let taper = rect.height * 0.13
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + taper))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - taper))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Controls

private struct ControlCluster: View {
    var body: some View {
        GeometryReader { proxy in
            let W = proxy.size.width
            let H = proxy.size.height
            let clusterX = W * 0.858

            ZStack {
                SpeedKnob()
                    .frame(width: H * 0.128, height: H * 0.128)
                    .position(x: clusterX, y: H * 0.770)

                ToggleSwitch()
                    .frame(width: H * 0.029, height: H * 0.085)
                    .position(x: clusterX - W * 0.042, y: H * 0.485)

                // Braun's quiet green power light.
                Circle()
                    .fill(Color(red: 0.42, green: 0.68, blue: 0.31))
                    .frame(width: H * 0.009, height: H * 0.009)
                    .shadow(color: Color(red: 0.50, green: 0.82, blue: 0.34).opacity(0.35), radius: H * 0.003)
                    .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
                    .position(x: clusterX + W * 0.043, y: H * 0.485)

            }
        }
    }
}


private struct SpeedKnob: View {
    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)

            ZStack {
                // Recess the knob sits in.
                Circle()
                    .fill(.black.opacity(0.24))
                    .blur(radius: d * 0.024)
                    .frame(width: d * 0.96, height: d * 0.96)
                    .offset(SceneLight.shadowOffset(-d * 0.010))

                // Knob body: aluminum, lit from the key light.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.87, blue: 0.845),
                                Color(red: 0.58, green: 0.57, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(d * 0.080)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .black.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                        .padding(d * 0.080)
                    )
                    .shadow(
                        color: .black.opacity(0.45),
                        radius: d * 0.030,
                        x: SceneLight.shadowOffset(d * 0.040).width,
                        y: SceneLight.shadowOffset(d * 0.040).height
                    )

                // Machined dome falloff.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.26), .clear, .black.opacity(0.16)],
                            center: UnitPoint(x: 0.32, y: 0.28),
                            startRadius: 0,
                            endRadius: d * 0.48
                        )
                    )
                    .padding(d * 0.080)

                // Indicator groove, set to 33.
                Capsule()
                    .fill(.black.opacity(0.55))
                    .frame(width: max(1, d * 0.020), height: d * 0.19)
                    .offset(y: -d * 0.18)
                    .rotationEffect(.degrees(-36))
                Capsule()
                    .fill(.white.opacity(0.20))
                    .frame(width: max(0.5, d * 0.007), height: d * 0.19)
                    .offset(x: d * 0.007, y: -d * 0.18)
                    .rotationEffect(.degrees(-36))
            }
            .frame(width: d, height: d)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct ToggleSwitch: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // Recessed plate machined into the face.
                RoundedRectangle(cornerRadius: w * 0.35, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.57, blue: 0.55),
                                Color(red: 0.70, green: 0.69, blue: 0.67)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: w * 1.9, height: h * 1.24)
                RoundedRectangle(cornerRadius: w * 0.35, style: .continuous)
                    .stroke(.black.opacity(0.28), lineWidth: 0.7)
                    .frame(width: w * 1.9, height: h * 1.24)
                RoundedRectangle(cornerRadius: w * 0.35, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 0.7)
                    .frame(width: w * 1.9, height: h * 1.24)
                    .offset(y: 1)
                    .mask(
                        Rectangle()
                            .frame(width: w * 3, height: h * 0.3)
                            .offset(y: h * 0.62)
                    )

                // Slot the lever travels in.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0.65), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w * 0.42, height: h * 0.94)

                // Lever, pushed to the top position.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.90, green: 0.89, blue: 0.87),
                                Color(red: 0.48, green: 0.47, blue: 0.45)
                            ],
                            center: UnitPoint(x: 0.34, y: 0.28),
                            startRadius: 0,
                            endRadius: w * 0.75
                        )
                    )
                    .overlay(Circle().stroke(.black.opacity(0.32), lineWidth: 0.6))
                    .frame(width: w * 1.05, height: w * 1.05)
                    .offset(y: -h * 0.26)
                    .shadow(
                        color: .black.opacity(0.45),
                        radius: 1.4,
                        x: SceneLight.shadowOffset(2.4).width,
                        y: SceneLight.shadowOffset(2.4).height
                    )
            }
        }
    }
}

private struct DeckDetails: View {
    let corner: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let W = proxy.size.width
            let H = proxy.size.height

            // Hinge slots recessed into the top edge: dark where the hole
            // swallows the light, a bright lip on the far side.
            HStack(spacing: H * 0.022) {
                ForEach(0..<2, id: \.self) { _ in
                    ZStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.04), Color(white: 0.22)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 1.5)
                            .stroke(.black.opacity(0.45), lineWidth: 0.6)
                        RoundedRectangle(cornerRadius: 1.5)
                            .stroke(.white.opacity(0.40), lineWidth: 0.6)
                            .offset(y: 0.9)
                            .mask(
                                Rectangle()
                                    .frame(height: H * 0.006)
                                    .offset(y: H * 0.006)
                            )
                    }
                    .frame(width: H * 0.042, height: H * 0.012)
                }
            }
            .position(x: W * 0.76, y: H * 0.018)
        }
    }
}

private struct PanelScrew: View {
    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(.black.opacity(0.35))
                    .blur(radius: d * 0.10)
                    .offset(SceneLight.shadowOffset(d * 0.08))
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.68), Color(white: 0.18)],
                            center: UnitPoint(x: 0.30, y: 0.25),
                            startRadius: 0,
                            endRadius: d * 0.7
                        )
                    )
                Capsule()
                    .fill(.black.opacity(0.55))
                    .frame(width: d * 0.10, height: d * 0.55)
                    .rotationEffect(.degrees(32))
                Circle()
                    .stroke(.black.opacity(0.35), lineWidth: 0.5)
            }
            .frame(width: d, height: d)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

// MARK: - Shared texture helpers

private struct SurfaceGrain: View {
    let intensity: Double
    let seed: Double

    var body: some View {
        Rectangle()
            .fill(.gray)
            .colorEffect(
                ShaderLibrary.filmGrain(.float(intensity), .float(seed))
            )
            .blendMode(.softLight)
    }
}

private struct MaterialImperfections: View {
    let scratchesOpacity: Double
    let dustOpacity: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("DustTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .saturation(0)
                    .contrast(1.25)
                    .opacity(dustOpacity)
                    .blendMode(.softLight)

                Image("ScratchesTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .saturation(0)
                    .contrast(1.55)
                    .opacity(scratchesOpacity)
                    .blendMode(.screen)
            }
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

private struct WallpaperArtwork: View {
    let url: URL?

#if DEBUG
    private static let overrideImage: NSImage? = ProcessInfo.processInfo
        .environment["VINYL_SNAPSHOT_ART"]
        .flatMap { NSImage(contentsOfFile: $0) }
#endif

    var body: some View {
        Group {
#if DEBUG
            if let override = Self.overrideImage {
                Image(nsImage: override)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                remote
            }
#else
            remote
#endif
        }
        .clipped()
    }

    @ViewBuilder
    private var remote: some View {
        Group {
            if let url {
                AsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeInOut(duration: 0.35))
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    case .empty:
                        fallback
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipped()
    }

    private var fallback: some View {
        Color(red: 0.34, green: 0.11, blue: 0.075)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white.opacity(0.60))
            }
    }
}

private func materialNoise(_ index: Int, salt: Double) -> CGFloat {
    let raw = sin(Double(index) * 12.9898 + salt * 78.233) * 43_758.5453
    return CGFloat(raw - floor(raw))
}
