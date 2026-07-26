import SwiftUI

struct AlbumCanvasWallpaperView: View {
    let item: PlayingItem
    let snapshotDate: Date

    var body: some View {
        GeometryReader { proxy in
            let deckHeight = min(proxy.size.height * 0.79, proxy.size.width * 0.63)
            let deckWidth = deckHeight * 1.22

            ZStack {
                AgedWoodSurface()

                TurntableDeck(
                    item: item,
                    snapshotDate: snapshotDate
                )
                .frame(width: deckWidth, height: deckHeight)
                .rotationEffect(.degrees(-0.18))
                .offset(y: proxy.size.height * 0.01)
                .shadow(color: .black.opacity(0.44), radius: 24, y: 16)
                .zIndex(2)

                AmbientWindowLight()
                    .zIndex(3)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.30)],
                    center: .center,
                    startRadius: min(proxy.size.width, proxy.size.height) * 0.33,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.78
                )
                .allowsHitTesting(false)
                .zIndex(4)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct AgedWoodSurface: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.17, green: 0.105, blue: 0.070)

                Image("RosewoodTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .rotationEffect(.degrees(90))
                    .scaleEffect(1.08)
                    .contrast(0.94)
                    .saturation(0.76)
                    .brightness(-0.075)

                Image("RosewoodRoughness")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .rotationEffect(.degrees(90))
                    .scaleEffect(1.08)
                    .contrast(1.35)
                    .opacity(0.16)
                    .blendMode(.softLight)

                Color(red: 0.36, green: 0.12, blue: 0.035)
                    .opacity(0.045)
                    .blendMode(.softLight)

                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    for scratch in 0..<34 {
                        let x = materialNoise(scratch, salt: 0.31) * size.width
                        let y = materialNoise(scratch, salt: 1.17) * size.height
                        let length = 14 + materialNoise(scratch, salt: 2.03) * 130
                        let slope = (materialNoise(scratch, salt: 2.89) - 0.5) * 5
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y + slope))
                        context.stroke(
                            path,
                            with: .color(
                                scratch.isMultiple(of: 5)
                                    ? .black.opacity(0.13)
                                    : .white.opacity(0.065)
                            ),
                            lineWidth: scratch.isMultiple(of: 5) ? 0.8 : 0.45
                        )
                    }

                    for dent in 0..<9 {
                        let x = materialNoise(dent, salt: 3.7) * size.width
                        let y = materialNoise(dent, salt: 4.9) * size.height
                        let width = 4 + materialNoise(dent, salt: 5.8) * 15
                        let height = 1.2 + materialNoise(dent, salt: 6.4) * 3
                        context.fill(
                            Path(
                                ellipseIn: CGRect(
                                    x: x,
                                    y: y,
                                    width: width,
                                    height: height
                                )
                            ),
                            with: .color(.black.opacity(0.14))
                        )
                    }
                }

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        .clear,
                        Color.black.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct AlbumSleeve: View {
    let artworkURL: URL?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size * 0.026

            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(white: 0.025))
                    .offset(x: size * 0.032, y: size * 0.040)
                    .blur(radius: size * 0.018)
                    .opacity(0.72)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(red: 0.83, green: 0.81, blue: 0.75))

                WallpaperArtwork(url: artworkURL)
                    .frame(width: size * 0.94, height: size * 0.94)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: radius * 0.72,
                            style: .continuous
                        )
                    )

                MaterialImperfections(
                    scratchesOpacity: 0.075,
                    dustOpacity: 0.12
                )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: radius,
                            style: .continuous
                        )
                    )

                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.28), location: 0),
                        .init(color: .clear, location: 0.18),
                        .init(color: .clear, location: 0.70),
                        .init(color: .black.opacity(0.18), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                )

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.30), lineWidth: 1)

                RoundedRectangle(cornerRadius: radius * 0.66, style: .continuous)
                    .stroke(.black.opacity(0.20), lineWidth: 1)
                    .padding(size * 0.029)

                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, canvasSize in
                    for nick in 0..<14 {
                        let edge = nick % 4
                        let location = materialNoise(nick, salt: 13.7)
                        let length = 1.2 + materialNoise(nick, salt: 14.4) * 4.2
                        var path = Path()

                        switch edge {
                        case 0:
                            path.move(to: CGPoint(x: location * canvasSize.width, y: 0.8))
                            path.addLine(to: CGPoint(x: location * canvasSize.width + length, y: 1.4))
                        case 1:
                            path.move(to: CGPoint(x: canvasSize.width - 0.8, y: location * canvasSize.height))
                            path.addLine(to: CGPoint(x: canvasSize.width - 1.4, y: location * canvasSize.height + length))
                        case 2:
                            path.move(to: CGPoint(x: location * canvasSize.width, y: canvasSize.height - 0.8))
                            path.addLine(to: CGPoint(x: location * canvasSize.width + length, y: canvasSize.height - 1.5))
                        default:
                            path.move(to: CGPoint(x: 0.8, y: location * canvasSize.height))
                            path.addLine(to: CGPoint(x: 1.4, y: location * canvasSize.height + length))
                        }

                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.34)),
                            lineWidth: 0.8
                        )
                    }
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
            }
        }
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

private struct TurntableDeck: View {
    let item: PlayingItem
    let snapshotDate: Date

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let inset = height * 0.022
            let recordSize = height * 0.94
            let recordX = width * 0.405
            let recordY = height * 0.50
            let panelWidth = width * 0.175

            ZStack {
                RoundedRectangle(cornerRadius: height * 0.018, style: .continuous)
                    .fill(Color(white: 0.18))
                    .offset(y: height * 0.012)

                BrushedMetalDeck(cornerRadius: height * 0.018)
                    .frame(width: width - inset * 2, height: height - inset * 2)
                    .shadow(color: .black.opacity(0.46), radius: 4, y: 4)

                PlatterRim()
                    .frame(width: recordSize * 1.025, height: recordSize * 1.025)
                    .position(x: recordX, y: recordY)

                SpinningRecord(
                    item: item,
                    snapshotDate: snapshotDate
                )
                .frame(width: recordSize, height: recordSize)
                .position(x: recordX, y: recordY)

                ControlPanel()
                    .frame(width: panelWidth, height: height * 0.92)
                    .position(
                        x: width - inset - panelWidth * 0.55,
                        y: height * 0.50
                    )

                TonearmAssembly()

                DeckHardware()

                LinearGradient(
                    colors: [
                        .white.opacity(0.09),
                        .clear,
                        .black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: height * 0.018,
                        style: .continuous
                    )
                )
                .allowsHitTesting(false)
            }
        }
    }
}

private struct BrushedMetalDeck: View {
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.82, green: 0.815, blue: 0.78), location: 0),
                                .init(color: Color(red: 0.74, green: 0.735, blue: 0.70), location: 0.24),
                                .init(color: Color(red: 0.68, green: 0.67, blue: 0.63), location: 0.56),
                                .init(color: Color(red: 0.59, green: 0.58, blue: 0.54), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image("MetalTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .saturation(0)
                    .contrast(1.28)
                    .opacity(0.11)
                    .blendMode(.multiply)

                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    let spacing = max(2.2, size.height / 180)
                    var y: CGFloat = 0
                    var line = 0

                    while y < size.height {
                        let opacity = line.isMultiple(of: 5) ? 0.028 : 0.013
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y + 0.4))
                        context.stroke(
                            path,
                            with: .color(.white.opacity(opacity)),
                            lineWidth: 0.42
                        )
                        y += spacing
                        line += 1
                    }
                }

                MaterialImperfections(
                    scratchesOpacity: 0.028,
                    dustOpacity: 0.040
                )

                MetalAgeMarks()

                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.17), location: 0),
                        .init(color: .clear, location: 0.16),
                        .init(color: .clear, location: 0.74),
                        .init(color: .black.opacity(0.16), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                shape
                    .stroke(.white.opacity(0.35), lineWidth: 1)

                shape
                    .inset(by: 2)
                    .stroke(.black.opacity(0.22), lineWidth: 1)
            }
            .clipShape(shape)
        }
    }
}

private struct MetalAgeMarks: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<7) { mark in
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .black.opacity(mark.isMultiple(of: 3) ? 0.08 : 0.045),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: proxy.size.width * 0.045
                            )
                        )
                        .frame(
                            width: proxy.size.width
                                * (0.035 + materialNoise(mark, salt: 21.4) * 0.08),
                            height: proxy.size.height
                                * (0.018 + materialNoise(mark, salt: 22.8) * 0.045)
                        )
                        .position(
                            x: proxy.size.width
                                * (0.04 + materialNoise(mark, salt: 23.6) * 0.92),
                            y: proxy.size.height
                                * (0.05 + materialNoise(mark, salt: 24.7) * 0.90)
                        )
                        .blur(radius: 3)
                }
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

private struct PlatterRim: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(white: 0.19), location: 0.84),
                            .init(color: Color(white: 0.55), location: 0.89),
                            .init(color: Color(white: 0.16), location: 0.94),
                            .init(color: Color(white: 0.055), location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.52),
                            .black.opacity(0.42),
                            .white.opacity(0.18),
                            .black.opacity(0.30),
                            .white.opacity(0.52)
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .padding(2)
        }
        .shadow(color: .black.opacity(0.43), radius: 8, y: 6)
    }
}

private struct SpinningRecord: View {
    let item: PlayingItem
    let snapshotDate: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !item.isPlaying)) { context in
            VinylDisc(artworkURL: item.artworkURL)
                .rotationEffect(rotation(at: context.date))
        }
    }

    private func rotation(at date: Date) -> Angle {
        let snapshotProgress = Double(item.progressMilliseconds ?? 0) / 1_000
        let elapsed = item.isPlaying ? max(0, date.timeIntervalSince(snapshotDate)) : 0
        return .degrees((snapshotProgress + elapsed) * 30)
    }
}

private struct VinylDisc: View {
    let artworkURL: URL?

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(white: 0.105), location: 0),
                                .init(color: Color(white: 0.055), location: 0.25),
                                .init(color: Color(white: 0.018), location: 0.72),
                                .init(color: .black, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter * 0.50
                        )
                    )

                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)

                    for ring in 0..<58 {
                        let irregularity = materialNoise(ring, salt: 15.2) * 0.0018
                        let radius = size.width
                            * (0.172 + CGFloat(ring) * 0.00555 + irregularity)
                        let bounds = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.stroke(
                            Path(ellipseIn: bounds),
                            with: .color(
                                .white.opacity(
                                    ring.isMultiple(of: 9)
                                        ? 0.10
                                        : 0.020 + Double(materialNoise(ring, salt: 16.4)) * 0.025
                                )
                            ),
                            lineWidth: ring.isMultiple(of: 9) ? 1.05 : 0.38
                        )
                    }

                    for dust in 0..<42 {
                        let angle = materialNoise(dust, salt: 8.1) * .pi * 2
                        let radius = size.width
                            * (0.19 + materialNoise(dust, salt: 9.2) * 0.285)
                        let x = center.x + cos(angle) * radius
                        let y = center.y + sin(angle) * radius
                        let speck = CGRect(
                            x: x,
                            y: y,
                            width: 0.6 + materialNoise(dust, salt: 10.2) * 1.5,
                            height: 0.35 + materialNoise(dust, salt: 11.3) * 0.7
                        )
                        context.fill(
                            Path(ellipseIn: speck),
                            with: .color(
                                .white.opacity(
                                    0.08 + Double(materialNoise(dust, salt: 12.2)) * 0.13
                                )
                            )
                        )
                    }
                }

                MaterialImperfections(
                    scratchesOpacity: 0.050,
                    dustOpacity: 0.075
                )
                .clipShape(Circle())
                .padding(diameter * 0.012)

                VinylPatina()
                    .padding(diameter * 0.012)

                RecordWear()
                    .padding(diameter * 0.018)

                Circle()
                    .fill(
                        AngularGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.13), location: 0.09),
                                .init(color: .clear, location: 0.21),
                                .init(color: .clear, location: 0.56),
                                .init(color: .white.opacity(0.055), location: 0.69),
                                .init(color: .clear, location: 0.78),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center
                        )
                    )
                    .blendMode(.screen)

                WallpaperArtwork(url: artworkURL)
                    .frame(width: diameter * 0.285, height: diameter * 0.285)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.50), lineWidth: 1.2)
                    }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(white: 0.38)],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: diameter * 0.025
                        )
                    )
                    .frame(width: diameter * 0.024, height: diameter * 0.024)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .compositingGroup()
        }
    }
}

private struct VinylPatina: View {
    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)

            ZStack {
                ForEach(0..<7) { band in
                    Circle()
                        .stroke(
                            AngularGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(
                                        color: .white.opacity(
                                            0.018
                                                + Double(
                                                    materialNoise(
                                                        band,
                                                        salt: 27.1
                                                    )
                                                ) * 0.035
                                        ),
                                        location: 0.17
                                    ),
                                    .init(color: .clear, location: 0.34),
                                    .init(color: .clear, location: 0.66),
                                    .init(
                                        color: .white.opacity(
                                            band.isMultiple(of: 3) ? 0.045 : 0.022
                                        ),
                                        location: 0.80
                                    ),
                                    .init(color: .clear, location: 1)
                                ],
                                center: .center
                            ),
                            lineWidth: diameter
                                * (0.006 + materialNoise(band, salt: 28.4) * 0.010)
                        )
                        .padding(
                            diameter
                                * (0.055 + CGFloat(band) * 0.038)
                        )
                        .blur(radius: 0.55)
                }

                Circle()
                    .stroke(.white.opacity(0.085), lineWidth: 1.1)
                    .padding(diameter * 0.325)

                Circle()
                    .stroke(.black.opacity(0.24), lineWidth: diameter * 0.012)
                    .padding(diameter * 0.292)
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

private struct RecordWear: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for scratch in 0..<5 {
                    let radius = size.width
                        * (0.27 + materialNoise(scratch, salt: 18.6) * 0.20)
                    let start = Angle.degrees(
                        Double(materialNoise(scratch, salt: 19.4) * 330)
                    )
                    let sweep = 8
                        + Double(materialNoise(scratch, salt: 20.2) * 34)
                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: start,
                        endAngle: start + .degrees(sweep),
                        clockwise: false
                    )
                    context.stroke(
                        path,
                        with: .color(.white.opacity(scratch == 2 ? 0.13 : 0.07)),
                        lineWidth: scratch == 2 ? 0.72 : 0.46
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}

private struct TonearmAssembly: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let pivot = CGPoint(x: width * 0.865, y: height * 0.105)
            let stylus = CGPoint(x: width * 0.605, y: height * 0.715)
            let thickness = height * 0.014

            let armPath = Path { path in
                path.move(to: pivot)
                path.addCurve(
                    to: stylus,
                    control1: CGPoint(x: width * 0.82, y: height * 0.30),
                    control2: CGPoint(x: width * 0.69, y: height * 0.60)
                )
            }

            ZStack {
                armPath
                    .stroke(
                        .black.opacity(0.34),
                        style: StrokeStyle(
                            lineWidth: thickness * 1.85,
                            lineCap: .round
                        )
                    )
                    .offset(x: 3, y: 5)
                    .blur(radius: 2.5)

                armPath
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.86, green: 0.85, blue: 0.81),
                                Color(white: 0.43),
                                Color(red: 0.92, green: 0.91, blue: 0.87)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: thickness,
                            lineCap: .round
                        )
                    )

                ZStack {
                    Circle()
                        .fill(Color(white: 0.075))
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .white.opacity(0.65),
                                    .black.opacity(0.60),
                                    .white.opacity(0.24),
                                    .white.opacity(0.65)
                                ],
                                center: .center
                            ),
                            lineWidth: height * 0.013
                        )
                        .padding(height * 0.010)
                    Circle()
                        .fill(Color(white: 0.19))
                        .padding(height * 0.045)
                }
                .frame(width: height * 0.135, height: height * 0.135)
                .position(pivot)
                .shadow(color: .black.opacity(0.42), radius: 6, y: 4)

                RoundedRectangle(cornerRadius: height * 0.016, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.64),
                                Color(white: 0.18),
                                Color(white: 0.48)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: height * 0.13, height: height * 0.067)
                    .rotationEffect(.degrees(18))
                    .position(
                        x: pivot.x + height * 0.055,
                        y: pivot.y - height * 0.050
                    )
                    .shadow(color: .black.opacity(0.34), radius: 3, y: 3)

                Headshell()
                    .frame(width: height * 0.12, height: height * 0.075)
                    .rotationEffect(.degrees(30))
                    .position(stylus)
                    .shadow(color: .black.opacity(0.46), radius: 4, y: 3)

                Capsule()
                    .fill(Color(red: 0.52, green: 0.075, blue: 0.050))
                    .frame(width: height * 0.006, height: height * 0.050)
                    .rotationEffect(.degrees(30))
                    .position(
                        x: stylus.x - height * 0.034,
                        y: stylus.y + height * 0.045
                    )
            }
        }
    }
}

private struct Headshell: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: proxy.size.height * 0.20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.16),
                                Color(white: 0.025)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                MaterialImperfections(
                    scratchesOpacity: 0.085,
                    dustOpacity: 0.045
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: proxy.size.height * 0.20
                    )
                )

                HStack(spacing: proxy.size.width * 0.11) {
                    Capsule()
                        .fill(.white.opacity(0.20))
                    Capsule()
                        .fill(.white.opacity(0.20))
                }
                .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 0.16)
            }
        }
    }
}

private struct ControlPanel: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: width * 0.065, style: .continuous)
                    .fill(Color(white: 0.045))
                    .overlay {
                        Image("LeatherTexture")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .contrast(1.45)
                            .brightness(-0.10)
                            .opacity(0.58)
                            .blendMode(.softLight)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: width * 0.065,
                                    style: .continuous
                                )
                            )
                    }
                    .overlay {
                        MaterialImperfections(
                            scratchesOpacity: 0.035,
                            dustOpacity: 0.050
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: width * 0.065,
                                style: .continuous
                            )
                        )
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: width * 0.065,
                            style: .continuous
                        )
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                    }

                PanelScrew()
                    .frame(width: width * 0.13, height: width * 0.13)
                    .position(x: width * 0.50, y: height * 0.065)

                VStack(spacing: height * 0.018) {
                    Text("33")
                    Capsule()
                        .frame(width: width * 0.038, height: height * 0.16)
                    Text("45")
                }
                .font(.system(size: max(7, width * 0.09), weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
                .position(x: width * 0.28, y: height * 0.31)

                Capsule()
                    .fill(.black.opacity(0.60))
                    .frame(width: width * 0.10, height: height * 0.22)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.84),
                                        Color(white: 0.31)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width * 0.28, height: height * 0.042)
                            .offset(y: height * 0.055)
                    }
                    .position(x: width * 0.67, y: height * 0.33)

                SpeedDial()
                    .frame(width: width * 0.67, height: width * 0.67)
                    .position(x: width * 0.51, y: height * 0.72)

                HStack(spacing: width * 0.19) {
                    Text("–")
                    Text("+")
                }
                .font(.system(size: max(8, width * 0.13), weight: .regular))
                .foregroundStyle(.white.opacity(0.48))
                .position(x: width * 0.50, y: height * 0.865)

                PanelScrew()
                    .frame(width: width * 0.13, height: width * 0.13)
                    .position(x: width * 0.50, y: height * 0.945)
            }
        }
    }
}

private struct PanelScrew: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.52), Color(white: 0.12)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 12
                    )
                )
            Capsule()
                .fill(.black.opacity(0.55))
                .frame(width: 2, height: 8)
                .rotationEffect(.degrees(32))
        }
        .shadow(color: .black.opacity(0.40), radius: 1, y: 1)
    }
}

private struct SpeedDial: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                ForEach(0..<12) { tick in
                    Capsule()
                        .fill(
                            tick == 2
                                ? Color(red: 0.40, green: 0.48, blue: 0.25).opacity(0.72)
                                : tick == 5 || tick == 8
                                    ? Color(red: 0.60, green: 0.22, blue: 0.13).opacity(0.68)
                                    : .white.opacity(tick.isMultiple(of: 3) ? 0.42 : 0.22)
                        )
                        .frame(width: 1, height: size * 0.075)
                        .offset(y: -size * 0.42)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.85, green: 0.84, blue: 0.72),
                                Color(red: 0.65, green: 0.63, blue: 0.52)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.45
                        )
                    )
                    .padding(size * 0.10)

                Circle()
                    .fill(Color(white: 0.13))
                    .padding(size * 0.25)

                Capsule()
                    .fill(.white.opacity(0.78))
                    .frame(width: 2, height: size * 0.16)
                    .offset(y: -size * 0.13)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .shadow(color: .black.opacity(0.36), radius: 3, y: 2)
        }
    }
}

private struct DeckHardware: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                let screwPoints = [
                    CGPoint(x: width * 0.066, y: height * 0.085),
                    CGPoint(x: width * 0.066, y: height * 0.915),
                    CGPoint(x: width * 0.936, y: height * 0.085),
                    CGPoint(x: width * 0.936, y: height * 0.915)
                ]

                ForEach(Array(screwPoints.enumerated()), id: \.offset) { _, point in
                    PanelScrew()
                        .frame(width: height * 0.030, height: height * 0.030)
                        .position(point)
                }

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.77, green: 0.055, blue: 0.028),
                                Color(red: 1.0, green: 0.25, blue: 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: height * 0.080, height: height * 0.028)
                    .position(x: width * 0.735, y: height * 0.905)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(white: 0.055))
                    .frame(width: width * 0.135, height: height * 0.044)
                    .overlay {
                        HStack(spacing: height * 0.010) {
                            Circle()
                                .stroke(.white.opacity(0.52), lineWidth: 1)
                                .frame(width: height * 0.022, height: height * 0.022)

                            Text("33 studio")
                                .font(
                                    .system(
                                        size: max(7, height * 0.022),
                                        weight: .regular,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 0.7)
                    }
                    .position(x: width * 0.105, y: height * 0.905)
                    .rotationEffect(.degrees(-0.6))
                    .shadow(color: .black.opacity(0.24), radius: 1, y: 1)

                HStack(spacing: height * 0.018) {
                    ForEach(0..<2) { hinge in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.76),
                                        Color(white: 0.32)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 1)
                                    .stroke(.black.opacity(0.26), lineWidth: 0.7)
                            }
                            .frame(width: height * 0.055, height: height * 0.018)
                    }
                }
                .position(x: width * 0.78, y: height * 0.035)
            }
        }
    }
}

private struct AmbientWindowLight: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 5.0)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let drift = sin(time * 0.075) * 0.018
                let warmth = 0.94
                    + sin(time * 0.34) * 0.025
                    + sin(time * 0.71) * 0.010

                ZStack {
                    RadialGradient(
                        stops: [
                            .init(
                                color: Color(
                                    red: 1.0,
                                    green: 0.73,
                                    blue: 0.43
                                ).opacity(0.15),
                                location: 0
                            ),
                            .init(
                                color: Color(
                                    red: 1.0,
                                    green: 0.82,
                                    blue: 0.61
                                ).opacity(0.060),
                                location: 0.38
                            ),
                            .init(color: .clear, location: 0.78)
                        ],
                        center: UnitPoint(x: 0.18 + drift, y: 0.15),
                        startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.70
                    )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blendMode(.screen)

                    RadialGradient(
                        colors: [
                            .black.opacity(0.055),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.73 - drift * 0.5,
                            y: 0.68 + drift * 0.4
                        ),
                        startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.58
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blendMode(.multiply)
                }
                .opacity(warmth)
                .compositingGroup()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WallpaperArtwork: View {
    let url: URL?

    var body: some View {
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
