import SwiftUI

struct PlaybackActions {
    var previous: (() -> Void)?
    var playPause: (() -> Void)?
    var next: (() -> Void)?
    var isAvailable: Bool { previous != nil && playPause != nil && next != nil }
}

struct ModernWallpaperView: View {
    let item: PlayingItem
    let snapshotDate: Date
    let appearance: AppearanceConfiguration
    let animation: AnimationConfiguration
    var playbackActions = PlaybackActions()
    var sceneExposure = 0.0
    var displayName: String?
    var identificationNumber: Int?

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        GeometryReader { proxy in
            let design = ThemeDesign(theme: appearance.theme, seed: item.id)
            let layout = WallpaperLayout(size: proxy.size, mode: appearance.layout, design: design)
            ZStack {
                ThemeBackground(item: item, appearance: appearance, design: design)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
                if design.theme == .midnight {
                    FixedMidnightScene(
                        item:item,snapshotDate:snapshotDate,appearance:appearance,
                        animation:animation,design:design,playbackActions:playbackActions,
                        reduceMotion:systemReduceMotion || animation.reduceMotionOverride,
                        scale:layout.sceneScale
                    )
                    .position(layout.deckCenter)
                    .allowsHitTesting(false)
                } else {
                    PremiumDeck(item: item, snapshotDate: snapshotDate, appearance: appearance,
                                animation: animation, design: design, playbackActions: playbackActions,
                                reduceMotion: systemReduceMotion || animation.reduceMotionOverride)
                        .frame(width: layout.deck.width, height: layout.deck.height)
                        .rotationEffect(.degrees(design.deckTilt))
                        .position(layout.deckCenter)
                        .allowsHitTesting(false)
                }

                if design.theme != .midnight && appearance.nowPlaying != .hidden {
                    NowPlayingPanel(item: item, style: appearance.nowPlaying, design: design, playbackActions: playbackActions)
                        .scaleEffect(appearance.nowPlayingScale)
                        .opacity(appearance.nowPlayingOpacity * (item.isPlaying ? 1 : 0.72))
                        .frame(width: layout.infoWidth)
                        .position(layout.infoCenter)
                }
                if let identificationNumber {
                    DisplayIdentification(number: identificationNumber, name: displayName ?? "Display")
                }
            }
            .colorEffect(ShaderLibrary.sceneExposure(.float(Float(sceneExposure))))
            .animation(.easeInOut(duration: transitionDuration), value: item.id)
            .animation(.easeInOut(duration: 0.55), value: appearance)
            .frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }.ignoresSafeArea()
    }

    private var transitionDuration: Double {
        if systemReduceMotion || animation.reduceMotionOverride { return 0.15 }
        return switch animation.style { case .minimal: 0.2; case .smooth: 0.75 / animation.speed; case .physical: 1.6 / animation.speed }
    }
}

/// Midnight is authored once in this immutable logical coordinate space.
/// The wrapper itself changes size, while the scene's internal proposal never
/// changes, avoiding monitor-dependent GeometryReader recomputation.
private struct FixedMidnightScene: View {
    static let designSize = CGSize(width:1920,height:1000)
    let item:PlayingItem, snapshotDate:Date, appearance:AppearanceConfiguration
    let animation:AnimationConfiguration, design:ThemeDesign
    let playbackActions:PlaybackActions
    let reduceMotion:Bool, scale:CGFloat
    var body:some View {
        Color.clear
            .frame(width:Self.designSize.width*scale,height:Self.designSize.height*scale)
            .overlay {
                MidnightDeck(item:item,snapshotDate:snapshotDate,appearance:appearance,
                             animation:animation,design:design,playbackActions:playbackActions,
                             reduceMotion:reduceMotion)
                    .frame(width:Self.designSize.width,height:Self.designSize.height)
                    .scaleEffect(scale,anchor:.center)
            }
            // Preserve vector edge coverage when the immutable design canvas
            // is scaled to a display's native backing dimensions.
            .clipped(antialiased:true)
    }
}

private enum DeckSilhouette { case monolith, slab, console, capsule, glass, split, vintage, gramophone }
private enum ArmKind { case straight, studio, sShape, lowProfile, brass }
private enum PanelKind { case glass, rail, console, label, floating, plaque }

private struct ThemeDesign {
    let theme: VinylTheme
    let top: Color, bottom: Color, metal: Color, accent: Color, background: Color
    let silhouette: DeckSilhouette, arm: ArmKind, panel: PanelKind
    let isLight: Bool, wood: Bool, glossy: Bool, translucent: Bool
    let platterX: CGFloat, platterScale: CGFloat, corner: CGFloat, deckRatio: CGFloat, deckTilt: Double
    let name: String, subtitle: String

    init(theme: VinylTheme, seed: String) {
        self.theme = theme
        let reactive = Self.reactive(seed)
        switch theme {
        case .midnight:
            (top,bottom,metal,accent,background)=(Color(white:0.115),Color(white:0.025),Color(white:0.62),Color(white:0.88),Color(red:0.008,green:0.01,blue:0.014))
            (silhouette,arm,panel)=(.monolith,.lowProfile,.rail); (isLight,wood,glossy,translucent)=(false,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.38,0.80,0.038,1.92,0); (name,subtitle)=("MIDNIGHT","MONOLITH SERIES")
        case .aurora:
            (top,bottom,metal,accent,background)=(Color(red:0.055,green:0.07,blue:0.13),Color(red:0.015,green:0.02,blue:0.055),Color(white:0.68),reactive,Color(red:0.008,green:0.012,blue:0.035))
            (silhouette,arm,panel)=(.capsule,.lowProfile,.floating); (isLight,wood,glossy,translucent)=(false,false,true,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.43,0.84,0.11,1.55,-1); (name,subtitle)=("AURORA","CHROMA DECK")
        case .studio:
            (top,bottom,metal,accent,background)=(Color(white:0.58),Color(white:0.27),Color(white:0.86),Color(red:0.55,green:0.78,blue:0.95),Color(white:0.055))
            (silhouette,arm,panel)=(.console,.studio,.console); (isLight,wood,glossy,translucent)=(false,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.36,0.76,0.018,1.62,0); (name,subtitle)=("STUDIO 33","REFERENCE MONITOR")
        case .porcelain:
            (top,bottom,metal,accent,background)=(Color(red:0.98,green:0.97,blue:0.93),Color(red:0.72,green:0.73,blue:0.72),Color(white:0.72),Color(red:0.38,green:0.56,blue:0.63),Color(red:0.72,green:0.73,blue:0.71))
            (silhouette,arm,panel)=(.capsule,.straight,.label); (isLight,wood,glossy,translucent)=(true,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.42,0.78,0.14,1.46,0); (name,subtitle)=("PORCELAIN","QUIET OBJECT NO. 1")
        case .obsidian:
            (top,bottom,metal,accent,background)=(Color(white:0.16),Color.black,Color(white:0.92),Color(white:0.72),Color.black)
            (silhouette,arm,panel)=(.slab,.lowProfile,.glass); (isLight,wood,glossy,translucent)=(false,false,true,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.40,0.82,0.025,1.52,0); (name,subtitle)=("OBSIDIAN","BLACK GLASS SYSTEM")
        case .transparent:
            (top,bottom,metal,accent,background)=(Color.white.opacity(0.18),Color.black.opacity(0.45),Color(white:0.78),reactive,Color(red:0.025,green:0.035,blue:0.05))
            (silhouette,arm,panel)=(.glass,.straight,.glass); (isLight,wood,glossy,translucent)=(false,false,true,true)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.38,0.77,0.045,1.58,0); (name,subtitle)=("TRANSPARENT","VISIBLE ARCHITECTURE")
        case .hiFi:
            (top,bottom,metal,accent,background)=(Color(white:0.31),Color(white:0.105),Color(white:0.74),Color(red:0.75,green:0.16,blue:0.09),Color(white:0.045))
            (silhouette,arm,panel)=(.slab,.studio,.console); (isLight,wood,glossy,translucent)=(false,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.39,0.79,0.022,1.44,0); (name,subtitle)=("HI–FI","INTEGRATED PLAYER")
        case .tokyo:
            (top,bottom,metal,accent,background)=(Color(white:0.24),Color(white:0.075),Color(white:0.57),Color(red:1,green:0.28,blue:0.07),Color(white:0.025))
            (silhouette,arm,panel)=(.console,.studio,.rail); (isLight,wood,glossy,translucent)=(false,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.35,0.75,0.012,1.68,0); (name,subtitle)=("TOKYO / 02","PRECISION AUDIO DEVICE")
        case .technics:
            (top,bottom,metal,accent,background)=(Color(white:0.76),Color(white:0.39),Color(white:0.86),Color(red:0.84,green:0.08,blue:0.06),Color(white:0.07))
            (silhouette,arm,panel)=(.console,.sShape,.console); (isLight,wood,glossy,translucent)=(true,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.39,0.78,0.012,1.53,-1.2); (name,subtitle)=("DIRECT DRIVE","QUARTZ PERFORMANCE")
        case .y2k:
            (top,bottom,metal,accent,background)=(Color(red:0.76,green:0.86,blue:0.88).opacity(0.78),Color(red:0.24,green:0.38,blue:0.42).opacity(0.72),Color(white:0.92),Color.cyan,Color(red:0.04,green:0.11,blue:0.14))
            (silhouette,arm,panel)=(.capsule,.straight,.floating); (isLight,wood,glossy,translucent)=(true,false,true,true)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.44,0.77,0.18,1.48,1); (name,subtitle)=("AQUA 2000","DIGITAL / ANALOG")
        case .seventies:
            (top,bottom,metal,accent,background)=(Color(red:0.42,green:0.20,blue:0.075),Color(red:0.12,green:0.045,blue:0.018),Color(white:0.66),Color(red:0.91,green:0.48,blue:0.13),Color(red:0.065,green:0.028,blue:0.012))
            (silhouette,arm,panel)=(.vintage,.sShape,.label); (isLight,wood,glossy,translucent)=(false,true,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.38,0.76,0.028,1.55,0); (name,subtitle)=("SEVENTIES","STEREO PHONOGRAPH")
        case .braun:
            (top,bottom,metal,accent,background)=(Color(red:0.86,green:0.85,blue:0.79),Color(red:0.60,green:0.60,blue:0.56),Color(white:0.35),Color(red:0.95,green:0.48,blue:0.08),Color(red:0.14,green:0.14,blue:0.12))
            (silhouette,arm,panel)=(.slab,.straight,.label); (isLight,wood,glossy,translucent)=(true,false,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.42,0.77,0.008,1.48,0); (name,subtitle)=("SYSTEM 1","PHONOGRAPH")
        case .walnut:
            (top,bottom,metal,accent,background)=(Color(red:0.34,green:0.15,blue:0.055),Color(red:0.085,green:0.03,blue:0.012),Color(white:0.73),Color(red:0.95,green:0.55,blue:0.20),Color(red:0.055,green:0.025,blue:0.012))
            (silhouette,arm,panel)=(.slab,.studio,.plaque); (isLight,wood,glossy,translucent)=(false,true,false,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.39,0.80,0.035,1.43,0); (name,subtitle)=("WALNUT","CRAFTED AUDIO")
        case .cream:
            (top,bottom,metal,accent,background)=(Color(red:0.94,green:0.84,blue:0.65),Color(red:0.61,green:0.48,blue:0.34),Color(white:0.88),Color(red:0.43,green:0.03,blue:0.08),Color(red:0.115,green:0.06,blue:0.045))
            (silhouette,arm,panel)=(.vintage,.sShape,.plaque); (isLight,wood,glossy,translucent)=(true,false,true,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.40,0.76,0.07,1.50,0.8); (name,subtitle)=("CREAM","DELUXE AUTOMATIC")
        case .gramophone:
            (top,bottom,metal,accent,background)=(Color(red:0.24,green:0.085,blue:0.025),Color(red:0.055,green:0.015,blue:0.005),Color(red:0.75,green:0.48,blue:0.14),Color(red:0.94,green:0.61,blue:0.22),Color.black)
            (silhouette,arm,panel)=(.gramophone,.brass,.plaque); (isLight,wood,glossy,translucent)=(false,true,true,false)
            (platterX,platterScale,corner,deckRatio,deckTilt)=(0.36,0.72,0.02,1.62,0); (name,subtitle)=("GRAMOPHONE","CLASSICAL REPRODUCER")
        }
    }
    private static func reactive(_ text: String) -> Color {
        let hash = text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.58, brightness: 0.86)
    }
}

private struct WallpaperLayout {
    let size: CGSize, mode: LayoutMode, design: ThemeDesign
    private static let midnightDesignSize = FixedMidnightScene.designSize
    var portrait: Bool { size.height > size.width }
    var sceneScale: CGFloat {
        guard design.theme == .midnight else { return 1 }
        let horizontalMargin: CGFloat = portrait ? 0.90 : 0.94
        let verticalMargin: CGFloat = portrait ? 0.90 : 0.88
        return min(
            size.width * horizontalMargin / Self.midnightDesignSize.width,
            size.height * verticalMargin / Self.midnightDesignSize.height
        )
    }
    var deck: CGSize {
        let heightLimit = size.height * design.deckRatio
        let width = portrait ? min(size.width * 0.90, size.height * 0.68) : min(size.width * 0.67, heightLimit)
        return CGSize(width: width, height: width / design.deckRatio)
    }
    var deckCenter: CGPoint {
        if portrait {
            return CGPoint(x:size.width*0.5,y:size.height*(design.theme == .midnight ? 0.36 : 0.38))
        }
        if mode == .turntableRight { return CGPoint(x:size.width*0.69,y:size.height*0.52) }
        if mode == .turntableLeft { return CGPoint(x:size.width*0.31,y:size.height*0.52) }
        let x: CGFloat = design.theme == .midnight ? 0.50:(design.panel == .floating ? 0.39 : (design.panel == .rail ? 0.43 : 0.40))
        return CGPoint(x:size.width*x,y:size.height*(design.theme == .midnight ? 0.53 : 0.52))
    }
    var infoWidth: CGFloat { portrait ? size.width*0.78 : min(size.width*(design.theme == .midnight ? 0.36:(design.panel == .rail ? 0.27:0.30)), 620) }
    var infoCenter: CGPoint {
        if portrait { return CGPoint(x:size.width*0.5,y:size.height*0.80) }
        if mode == .turntableRight { return CGPoint(x:size.width*0.21,y:size.height*0.52) }
        let y: CGFloat = design.theme == .midnight ? 0.66:(design.panel == .floating ? 0.43 : (design.panel == .plaque ? 0.58 : 0.52))
        return CGPoint(x:size.width*(design.theme == .midnight ? 0.75:0.81),y:size.height*y)
    }
}

private struct ThemeBackground: View {
    let item: PlayingItem, appearance: AppearanceConfiguration, design: ThemeDesign
    var body: some View {
        ZStack {
            design.background
            if design.theme == .midnight {
                MidnightStudioDesk()
            }
            if appearance.background == .albumBlur, let url = item.artworkURL {
                AsyncImage(url:url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                    .blur(radius:100).saturation(0.65).brightness(-0.45).scaleEffect(1.2)
            }
            if appearance.background == .gradient || appearance.background == .albumColours || design.theme == .aurora {
                RadialGradient(colors:[design.accent.opacity(design.theme == .aurora ? 0.38 : 0.16),.clear], center:.topLeading,startRadius:20,endRadius:900)
            }
            LinearGradient(colors:[.white.opacity(design.isLight ? 0.08 : 0.025),.clear,.black.opacity(0.44)],startPoint:.top,endPoint:.bottom)
            if design.theme == .studio || design.theme == .tokyo {
                GridTexture().opacity(0.07)
            }
            RadialGradient(colors:[.clear,.black.opacity(0.56)],center:.center,startRadius:120,endRadius:1100)
        }
    }
}

/// A lifted graphite studio surface keeps Midnight readable on displays with
/// very different black levels while preserving the dark, cinematic setting.
private struct MidnightStudioDesk: View {
    var body:some View {
        GeometryReader { proxy in
            let w=proxy.size.width,h=proxy.size.height
            ZStack {
                Color(red:0.027,green:0.025,blue:0.024)
                LinearGradient(
                    colors:[Color(red:0.105,green:0.091,blue:0.081),Color(red:0.058,green:0.053,blue:0.050),Color(red:0.020,green:0.020,blue:0.021)],
                    startPoint:.topLeading,endPoint:.bottomTrailing
                )
                RadialGradient(colors:[Color(red:0.43,green:0.26,blue:0.17).opacity(0.16),.clear],center:UnitPoint(x:0.10,y:0.13),startRadius:0,endRadius:max(w,h)*0.72)
                RadialGradient(colors:[.white.opacity(0.026),.clear],center:UnitPoint(x:0.48,y:0.55),startRadius:0,endRadius:max(w,h)*0.50)
                MidnightDeskGrain().opacity(0.30).blendMode(.softLight)
                // Broad floor shadow visually anchors the fixed turntable
                // scene to the desk rather than letting it float in space.
                Ellipse().fill(.black.opacity(0.46))
                    .frame(width:min(w*0.82,h*1.55),height:min(h*0.18,w*0.13))
                    .position(x:w*0.50,y:h*0.79).blur(radius:min(w,h)*0.038)
                RadialGradient(colors:[.clear,.black.opacity(0.54)],center:UnitPoint(x:0.46,y:0.44),startRadius:min(w,h)*0.22,endRadius:max(w,h)*0.78)
            }
            .frame(width:w,height:h)
        }
        .ignoresSafeArea()
    }
}

private struct MidnightDeskGrain: View {
    var body:some View {
        Canvas(opaque:false,colorMode:.linear,rendersAsynchronously:true) { context,size in
            // Deterministic, sub-point flecks give the surface real texture
            // without temporal shimmer or a visible repeating grain pattern.
            for index in 0..<1800 {
                let x = midnightNoise(index, salt: 71.3) * size.width
                let y = midnightNoise(index, salt: 19.7) * size.height
                let diameter = 0.18 + midnightNoise(index, salt: 43.1) * 0.55
                let bright = midnightNoise(index, salt: 91.9) > 0.50
                context.fill(
                    Path(ellipseIn:CGRect(x:x,y:y,width:diameter,height:diameter)),
                    with:.color(bright ? .white.opacity(0.075):.black.opacity(0.13))
                )
            }
        }
    }
}

private struct GridTexture: View {
    var body: some View { Canvas { context,size in
        var path=Path(); stride(from:0,through:size.width,by:48).forEach { path.move(to:CGPoint(x:$0,y:0)); path.addLine(to:CGPoint(x:$0,y:size.height)) }
        stride(from:0,through:size.height,by:48).forEach { path.move(to:CGPoint(x:0,y:$0)); path.addLine(to:CGPoint(x:size.width,y:$0)) }
        context.stroke(path,with:.color(.white),lineWidth:0.5)
    }}
}

private struct PremiumDeck: View {
    let item: PlayingItem, snapshotDate: Date, appearance: AppearanceConfiguration, animation: AnimationConfiguration, design: ThemeDesign
    let playbackActions: PlaybackActions
    let reduceMotion: Bool
    @ViewBuilder var body: some View {
        if design.theme == .midnight {
            MidnightDeck(item:item,snapshotDate:snapshotDate,appearance:appearance,animation:animation,design:design,playbackActions:playbackActions,reduceMotion:reduceMotion)
        } else { GeometryReader { p in
        let w=p.size.width,h=p.size.height,d=min(h*design.platterScale,w*0.60),c=CGPoint(x:w*design.platterX,y:h*0.50)
        ZStack {
            DeckShell(design:design).shadow(color:.black.opacity(0.68),radius:h*0.09,y:h*0.05)
            InternalDetails(design:design).padding(h*0.045)
            Circle().fill(.black.opacity(0.78)).overlay(Circle().stroke(design.metal.opacity(0.38),lineWidth:h*0.012)).frame(width:d*1.055,height:d*1.055).position(c)
            RecordView(item:item,snapshotDate:snapshotDate,appearance:appearance,design:design,reduceMotion:reduceMotion).frame(width:d,height:d).position(c)
                .shadow(color:design.accent.opacity(appearance.platterGlow ? appearance.lightingIntensity*0.45:0),radius:d*0.08)
            TonearmView(progress:item.progress ?? 0,playing:item.isPlaying,enabled:animation.tonearmMovement,design:design)
                .frame(width:w*0.34,height:h*0.82).position(x:w*0.80,y:h*0.49)
            ControlCluster(design:design,isPlaying:item.isPlaying).frame(width:w,height:h)
            Text(design.name).font(.system(size:h*0.025,weight:.semibold,design:.rounded)).tracking(h*0.006)
                .foregroundStyle(design.isLight ? .black.opacity(0.55):.white.opacity(0.55)).position(x:w*0.80,y:h*0.16)
        }
        }}
    }
}

private struct MidnightDeck: View {
    let item: PlayingItem, snapshotDate: Date, appearance: AppearanceConfiguration, animation: AnimationConfiguration, design: ThemeDesign
    let playbackActions: PlaybackActions
    let reduceMotion: Bool
    private var chassisDiagnostic: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["VINYL_CHASSIS_DIAGNOSTIC"] == "1"
#else
        false
#endif
    }
    var body: some View { GeometryReader { p in
        let w=p.size.width,h=p.size.height
        let d=min(h*0.755,w*0.445), center=CGPoint(x:w*0.345,y:h*0.375)
        ZStack {
            if chassisDiagnostic {
                MidnightChassisDiagnostic()
                    .modifier(PhysicalPlaneProjection(plane:.topDeck))
            } else {
            // Shadow is entirely below the enclosure; it must never become a
            // solid secondary chassis strip.
            Ellipse().fill(.black.opacity(0.62)).frame(width:w*0.74,height:h*0.040)
                .position(x:w*0.50,y:h*0.925).blur(radius:h*0.022)
            MidnightFoot().frame(width:w*0.034,height:h*0.012).position(x:w*0.18,y:h*0.905)
            MidnightFoot().frame(width:w*0.034,height:h*0.012).position(x:w*0.82,y:h*0.905)

            // A single master enclosure underlies both visible planes. The
            // derived surface/face paths meet on the same contour seam.
            MidnightChassisOuterShape()
                .fill(Color(red:0.070,green:0.064,blue:0.061))
                .shadow(color:.black.opacity(0.62),radius:3,y:3)
                .modifier(PhysicalPlaneProjection(plane:.topDeck))

            ZStack {
                MidnightPlinth(isPlaying:item.isPlaying,accent:design.accent)
            }
            .modifier(PhysicalPlaneProjection(plane:.frontPlinth))

            ZStack {
                MidnightTopShape()
                    .fill(LinearGradient(colors:[Color(red:0.190,green:0.178,blue:0.170),Color(white:0.092),Color(white:0.043)],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .overlay(MidnightMetalSurface(frontFacing:false).clipShape(MidnightTopShape()).opacity(0.80).blendMode(.softLight))
                    .shadow(color:.black.opacity(0.48),radius:2,y:2)
                RadialGradient(colors:[Color(red:0.92,green:0.47,blue:0.20).opacity(0.15),.clear],center:UnitPoint(x:0.08,y:0.10),startRadius:0,endRadius:w*0.42)
                    .clipShape(MidnightTopShape()).blendMode(.screen)
                LinearGradient(colors:[.clear,Color(red:0.70,green:0.76,blue:0.82).opacity(0.055)],startPoint:.leading,endPoint:.trailing)
                    .clipShape(MidnightTopShape()).blendMode(.screen)

            // Platter: lower shadow, thick graphite rim, machined edge and top mat.
                Ellipse().fill(.black.opacity(0.78)).frame(width:d*1.14,height:d*0.90).position(x:center.x,y:center.y+h*0.050).blur(radius:7)
                Ellipse().fill(LinearGradient(colors:[Color(red:0.52,green:0.48,blue:0.46),Color(white:0.22),Color(white:0.055)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:d*1.105,height:d*0.875).position(x:center.x,y:center.y+h*0.031)
                Ellipse().fill(LinearGradient(colors:[Color(white:0.27),Color(white:0.11),Color(white:0.035)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:d*1.075,height:d*0.84).position(x:center.x,y:center.y+h*0.016)
                ForEach(0..<3,id:\.self) { ring in
                    Ellipse().stroke(.white.opacity(0.075-Double(ring)*0.018),lineWidth:0.55)
                        .frame(width:d*(1.064-CGFloat(ring)*0.012),height:d*(0.829-CGFloat(ring)*0.010))
                        .position(x:center.x,y:center.y+h*0.015)
                }
                Ellipse().fill(Color(white:0.035)).frame(width:d*1.035,height:d*0.805).position(center)
            RecordView(item:item,snapshotDate:snapshotDate,appearance:appearance,design:design,reduceMotion:reduceMotion)
                .frame(width:d*0.98,height:d*0.98).scaleEffect(y:0.76)
                .position(x:center.x,y:center.y-h*0.004)
                .shadow(color:.black.opacity(0.75),radius:5,y:5)
                .shadow(color:design.accent.opacity(appearance.platterGlow ? appearance.lightingIntensity*0.24:0),radius:d*0.10)
                .transition(.offset(y:-18).combined(with:.opacity))

                MidnightTonearm(progress:item.progress ?? 0,playing:item.isPlaying,enabled:animation.tonearmMovement && item.id != PlayingItem.idle.id,metal:design.metal,accent:design.accent)
                    .frame(width:w*0.48,height:h*0.62).position(x:w*0.70,y:h*0.36)
                if appearance.nowPlaying != .hidden {
                    MidnightEmbeddedDisplay(item:item)
                        .frame(width:w*0.275,height:h*0.135)
                        .position(x:w*0.785,y:h*0.555)
                        .opacity(appearance.nowPlayingOpacity * (item.isPlaying ? 1:0.82))
                        .transition(.opacity)
                }
            }
            .modifier(PhysicalPlaneProjection(plane:.topDeck))
            }
        }
    }}
}

private enum PhysicalPlane { case topDeck, frontPlinth }

/// Every component mounted to a physical surface passes through the same
/// projection, including text and display content. This keeps those elements
/// from reading as screen-aligned overlays.
private struct PhysicalPlaneProjection: ViewModifier {
    let plane:PhysicalPlane
    func body(content:Content)->some View {
        switch plane {
        case .topDeck:
            content.rotation3DEffect(.degrees(2.8),axis:(x:1,y:0,z:0),anchor:.center,perspective:0.16)
        case .frontPlinth:
            // Both derived chassis planes share the same camera projection so
            // their master-contour seam remains pixel-identical. Bevel and
            // material response communicate the physical plane change.
            content.rotation3DEffect(.degrees(2.8),axis:(x:1,y:0,z:0),anchor:.center,perspective:0.16)
        }
    }
}

private struct MidnightMetalSurface: View {
    let frontFacing:Bool
    var body:some View { GeometryReader { p in
        Rectangle().fill(Color(white:0.5))
            .colorEffect(ShaderLibrary.brushedMetal(.float2(p.size.width,p.size.height),.float(frontFacing ? 31:17)))
            .mask(
                LinearGradient(
                    colors:[.white.opacity(frontFacing ? 0.58:0.72),.white.opacity(0.18),.white.opacity(frontFacing ? 0.42:0.26)],
                    startPoint:.topLeading,endPoint:.bottomTrailing
                )
            )
    }}
}

private enum ChassisOuterContour {
    static let backLeft=CGPoint(x:0.095,y:0.045),backLeftShoulder=CGPoint(x:0.13,y:0.015)
    static let backRightShoulder=CGPoint(x:0.87,y:0.015),backRight=CGPoint(x:0.915,y:0.055)
    // The top deck and front plinth share these exact outer seam endpoints.
    // Any inset here makes the top visibly overhang once the live wallpaper
    // settles at the display's final scale.
    static let rightFront=CGPoint(x:0.95,y:0.752),seamRight=CGPoint(x:0.95,y:0.775)
    // One engineered cross-section: a flush upper join, a straight drafted
    // fascia, one lower radius, then a short recessed underside.
    static let upperInsetRight=CGPoint(x:0.948,y:0.807),upperInsetLeft=CGPoint(x:0.042,y:0.807)
    static let faceLowerRight=CGPoint(x:0.944,y:0.890),faceLowerLeft=CGPoint(x:0.046,y:0.890)
    static let lowerRight=CGPoint(x:0.905,y:0.918),lowerLeft=CGPoint(x:0.085,y:0.918)
    static let seamLeft=CGPoint(x:0.04,y:0.775),leftFront=CGPoint(x:0.04,y:0.748)
    static let fasciaTopLeft=CGPoint(x:0.085,y:0.775),fasciaTopRight=CGPoint(x:0.905,y:0.775)
    static let fasciaBottomRight=CGPoint(x:0.905,y:0.890),fasciaBottomLeft=CGPoint(x:0.085,y:0.890)
    static func point(_ p:CGPoint,in r:CGRect)->CGPoint { CGPoint(x:r.width*p.x,y:r.height*p.y) }
}

/// Snapshot-only topology view. Each colour is a real, non-overlapping region
/// of the shared A–H chassis path, not a mask or corrective overlay.
private struct MidnightChassisDiagnostic: View {
    var body: some View {
        ZStack {
            // One continuous silhouette prevents antialiasing seams between
            // the centre face and its curved end regions. The matching stroke
            // tucks beneath the red/yellow layers to seal shared boundaries.
            ChassisDiagnosticBlueShape()
                .fill(.blue)
                .overlay(ChassisDiagnosticBlueShape().stroke(.blue,lineWidth:2))
            ChassisFullLowerLipShape().fill(.yellow)
            // The top shell is deliberately composited last: its lower corner
            // radii physically sit in front of the lower chassis surfaces.
            MidnightTopShape().fill(.red)
        }
    }
}

/// Unified diagnostic fascia: the centre and both curved ends are one path.
private struct ChassisDiagnosticBlueShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        p.move(to:c.point(c.leftFront,in:r))
        p.addCurve(
            to:c.point(CGPoint(x:0.075,y:0.785),in:r),
            control1:c.point(CGPoint(x:0.04,y:0.775),in:r),
            control2:c.point(CGPoint(x:0.055,y:0.785),in:r)
        )
        p.addLine(to:c.point(CGPoint(x:0.915,y:0.785),in:r))
        p.addCurve(
            to:c.point(CGPoint(x:0.95,y:0.748),in:r),
            control1:c.point(CGPoint(x:0.935,y:0.785),in:r),
            control2:c.point(CGPoint(x:0.95,y:0.775),in:r)
        )
        p.addLine(to:c.point(CGPoint(x:0.95,y:0.853),in:r))
        p.addCurve(
            to:c.point(CGPoint(x:0.915,y:0.890),in:r),
            control1:c.point(CGPoint(x:0.95,y:0.880),in:r),
            control2:c.point(CGPoint(x:0.935,y:0.890),in:r)
        )
        p.addLine(to:c.point(CGPoint(x:0.075,y:0.890),in:r))
        p.addCurve(
            to:c.point(CGPoint(x:0.04,y:0.853),in:r),
            control1:c.point(CGPoint(x:0.055,y:0.890),in:r),
            control2:c.point(CGPoint(x:0.04,y:0.880),in:r)
        )
        p.closeSubpath()
    }}
}

/// Thin lower lip whose top and bottom end curves are exact vertical
/// translations of the red shell's approved lower-corner Bezier.
private struct ChassisFullLowerLipShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        let x=0.037
        let topOuterLeft=CGPoint(x:0.04,y:0.890-x)
        let topInnerLeft=CGPoint(x:0.075,y:0.890)
        let topInnerRight=CGPoint(x:0.915,y:0.890)
        let topOuterRight=CGPoint(x:0.95,y:0.890-x)
        let bottomOuterRight=CGPoint(x:0.95,y:0.918-x)
        let bottomInnerRight=CGPoint(x:0.915,y:0.918)
        let bottomInnerLeft=CGPoint(x:0.075,y:0.918)
        let bottomOuterLeft=CGPoint(x:0.04,y:0.918-x)

        p.move(to:c.point(topOuterLeft,in:r))
        p.addCurve(to:c.point(topInnerLeft,in:r),
                   control1:c.point(CGPoint(x:0.04,y:0.890-0.010),in:r),
                   control2:c.point(CGPoint(x:0.055,y:0.890),in:r))
        p.addLine(to:c.point(topInnerRight,in:r))
        p.addCurve(to:c.point(topOuterRight,in:r),
                   control1:c.point(CGPoint(x:0.935,y:0.890),in:r),
                   control2:c.point(CGPoint(x:0.95,y:0.890-0.010),in:r))
        p.addLine(to:c.point(bottomOuterRight,in:r))
        p.addCurve(to:c.point(bottomInnerRight,in:r),
                   control1:c.point(CGPoint(x:0.95,y:0.918-0.010),in:r),
                   control2:c.point(CGPoint(x:0.935,y:0.918),in:r))
        p.addLine(to:c.point(bottomInnerLeft,in:r))
        p.addCurve(to:c.point(bottomOuterLeft,in:r),
                   control1:c.point(CGPoint(x:0.055,y:0.918),in:r),
                   control2:c.point(CGPoint(x:0.04,y:0.918-0.010),in:r))
        p.closeSubpath()
    }}
}

private struct ChassisCentreFasciaShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        // Meet the mirrored green wraps at their inner x boundaries.
        let b=CGPoint(x:0.075,y:c.fasciaTopLeft.y), cTop=CGPoint(x:0.915,y:c.fasciaTopRight.y)
        let f=CGPoint(x:0.915,y:c.fasciaBottomRight.y), g=CGPoint(x:0.075,y:c.fasciaBottomLeft.y)
        p.move(to:c.point(b,in:r))
        p.addLine(to:c.point(cTop,in:r))
        p.addLine(to:c.point(f,in:r))
        p.addLine(to:c.point(g,in:r))
        p.closeSubpath()
    }}
}

private struct ChassisLeftWrapShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        // The upper boundary is the red shell's lower-left Bezier copied in
        // reverse, so both surfaces share the exact same curve and anchors.
        let upperLeft=c.leftFront
        let upperRight=CGPoint(x:0.075,y:0.785)
        let lowerRight=CGPoint(x:upperRight.x,y:0.890)
        let lowerLeft=CGPoint(x:upperLeft.x,y:0.890-0.037)
        p.move(to:c.point(upperLeft,in:r))
        p.addCurve(
            to:c.point(upperRight,in:r),
            control1:c.point(CGPoint(x:0.04,y:0.775),in:r),
            control2:c.point(CGPoint(x:0.055,y:0.785),in:r)
        )
        p.addLine(to:c.point(lowerRight,in:r))
        p.addCurve(
            to:c.point(lowerLeft,in:r),
            control1:c.point(CGPoint(x:0.055,y:0.890),in:r),
            control2:c.point(CGPoint(x:0.04,y:0.880),in:r)
        )
        p.closeSubpath()
    }}
}

private struct ChassisRightWrapShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        // Exact horizontal mirror of ChassisLeftWrapShape around x = 0.495.
        func mirror(_ point:CGPoint)->CGPoint { CGPoint(x:0.99-point.x,y:point.y) }
        let leftUpperLeft=c.leftFront
        let leftUpperRight=CGPoint(x:0.075,y:0.785)
        let leftLowerRight=CGPoint(x:leftUpperRight.x,y:0.890)
        let leftLowerLeft=CGPoint(x:leftUpperLeft.x,y:0.890-0.037)

        p.move(to:c.point(mirror(leftUpperRight),in:r))
        p.addCurve(
            to:c.point(mirror(leftUpperLeft),in:r),
            control1:c.point(mirror(CGPoint(x:0.055,y:0.785)),in:r),
            control2:c.point(mirror(CGPoint(x:0.04,y:0.775)),in:r)
        )
        p.addLine(to:c.point(mirror(leftLowerLeft),in:r))
        p.addCurve(
            to:c.point(mirror(leftLowerRight),in:r),
            control1:c.point(mirror(CGPoint(x:0.04,y:0.880)),in:r),
            control2:c.point(mirror(CGPoint(x:0.055,y:0.890)),in:r)
        )
        p.closeSubpath()
    }}
}

private struct ChassisUndersideShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        p.move(to:c.point(CGPoint(x:0.075,y:c.lowerLeft.y),in:r))
        p.addLine(to:c.point(CGPoint(x:0.915,y:c.lowerRight.y),in:r))
        p.addLine(to:c.point(CGPoint(x:0.915,y:c.fasciaBottomRight.y),in:r))
        p.addLine(to:c.point(CGPoint(x:0.075,y:c.fasciaBottomLeft.y),in:r))
        p.closeSubpath()
    }}
}

private struct MidnightChassisOuterShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        p.move(to:c.point(c.backLeft,in:r)); p.addQuadCurve(to:c.point(c.backLeftShoulder,in:r),control:c.point(CGPoint(x:0.10,y:0.015),in:r))
        p.addLine(to:c.point(c.backRightShoulder,in:r)); p.addQuadCurve(to:c.point(c.backRight,in:r),control:c.point(CGPoint(x:0.905,y:0.015),in:r))
        p.addLine(to:c.point(c.rightFront,in:r)); p.addQuadCurve(to:c.point(c.seamRight,in:r),control:c.point(CGPoint(x:0.95,y:0.766),in:r))
        p.addCurve(to:c.point(c.fasciaTopRight,in:r),control1:c.point(CGPoint(x:0.945,y:0.775),in:r),control2:c.point(CGPoint(x:0.935,y:0.775),in:r))
        p.addLine(to:c.point(c.fasciaBottomRight,in:r))
        p.addCurve(to:c.point(c.lowerRight,in:r),control1:c.point(CGPoint(x:0.935,y:0.884),in:r),control2:c.point(CGPoint(x:0.930,y:0.895),in:r))
        p.addLine(to:c.point(c.lowerLeft,in:r))
        p.addCurve(to:c.point(c.fasciaBottomLeft,in:r),control1:c.point(CGPoint(x:0.060,y:0.895),in:r),control2:c.point(CGPoint(x:0.055,y:0.884),in:r))
        p.addLine(to:c.point(c.fasciaTopLeft,in:r))
        p.addCurve(to:c.point(c.seamLeft,in:r),control1:c.point(CGPoint(x:0.055,y:0.775),in:r),control2:c.point(CGPoint(x:0.045,y:0.775),in:r)); p.addQuadCurve(to:c.point(c.leftFront,in:r),control:c.point(CGPoint(x:0.04,y:0.766),in:r)); p.closeSubpath()
    }}
}

private struct MidnightTopShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        let redBottomRight=CGPoint(x:0.915,y:0.785)
        let redBottomLeft=CGPoint(x:0.075,y:0.785)
        p.move(to:c.point(c.backLeft,in:r)); p.addQuadCurve(to:c.point(c.backLeftShoulder,in:r),control:c.point(CGPoint(x:0.10,y:0.015),in:r))
        p.addLine(to:c.point(c.backRightShoulder,in:r)); p.addQuadCurve(to:c.point(c.backRight,in:r),control:c.point(CGPoint(x:0.905,y:0.015),in:r))
        p.addLine(to:c.point(c.rightFront,in:r))
        p.addCurve(
            to:c.point(redBottomRight,in:r),
            control1:c.point(CGPoint(x:0.95,y:0.775),in:r),
            control2:c.point(CGPoint(x:0.935,y:0.785),in:r)
        )
        p.addLine(to:c.point(redBottomLeft,in:r))
        p.addCurve(
            to:c.point(c.leftFront,in:r),
            control1:c.point(CGPoint(x:0.055,y:0.785),in:r),
            control2:c.point(CGPoint(x:0.04,y:0.775),in:r)
        )
        p.closeSubpath()
    }}
}

private struct MidnightFrontShape: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        p.move(to:c.point(c.seamLeft,in:r)); p.addCurve(to:c.point(c.fasciaTopLeft,in:r),control1:c.point(CGPoint(x:0.045,y:0.775),in:r),control2:c.point(CGPoint(x:0.055,y:0.775),in:r))
        p.addLine(to:c.point(c.fasciaTopRight,in:r))
        p.addCurve(to:c.point(c.seamRight,in:r),control1:c.point(CGPoint(x:0.935,y:0.775),in:r),control2:c.point(CGPoint(x:0.945,y:0.775),in:r))
        p.addCurve(to:c.point(c.lowerRight,in:r),control1:c.point(CGPoint(x:0.95,y:0.800),in:r),control2:c.point(CGPoint(x:0.945,y:0.895),in:r))
        p.addCurve(to:c.point(c.fasciaBottomRight,in:r),control1:c.point(CGPoint(x:0.930,y:0.895),in:r),control2:c.point(CGPoint(x:0.935,y:0.884),in:r))
        p.addLine(to:c.point(c.fasciaBottomLeft,in:r))
        p.addCurve(to:c.point(c.lowerLeft,in:r),control1:c.point(CGPoint(x:0.055,y:0.884),in:r),control2:c.point(CGPoint(x:0.060,y:0.895),in:r))
        p.addCurve(to:c.point(c.seamLeft,in:r),control1:c.point(CGPoint(x:0.045,y:0.895),in:r),control2:c.point(CGPoint(x:0.04,y:0.800),in:r))
        p.closeSubpath()
    }}
}

private struct MidnightPlinth: View {
    let isPlaying:Bool,accent:Color
    var body:some View { GeometryReader { p in
        let w=p.size.width,h=p.size.height
        let contentHeight=h*(0.856-0.788)*0.90
        // Centre the complete label/control group within the approved planar
        // fascia: its straight boundaries are y=0.785 and y=0.890.
        let opticalCenter=h*((0.785+0.890)/2)
        ZStack {
            // The approved diagnostic fascia is retained as one continuous
            // physical surface so material rendering cannot reintroduce seams.
            ChassisDiagnosticBlueShape()
                .fill(LinearGradient(
                    colors:[Color(red:0.172,green:0.157,blue:0.148),Color(white:0.092),Color(white:0.052)],
                    startPoint:.top,endPoint:.bottom
                ))
                .overlay(MidnightMetalSurface(frontFacing:true).clipShape(ChassisDiagnosticBlueShape()).opacity(0.92).blendMode(.softLight))
                .overlay(RadialGradient(colors:[.white.opacity(0.045),.clear],center:UnitPoint(x:0.50,y:0.81),startRadius:0,endRadius:w*0.48).clipShape(ChassisDiagnosticBlueShape()).blendMode(.screen))
                .overlay(LinearGradient(colors:[Color(red:0.72,green:0.55,blue:0.43).opacity(0.055),.white.opacity(0.025),.black.opacity(0.16)],startPoint:.leading,endPoint:.trailing).clipShape(ChassisDiagnosticBlueShape()).blendMode(.softLight))
                .shadow(color:.black.opacity(0.88),radius:h*0.040,y:h*0.036)

            ChassisFullLowerLipShape()
                .fill(LinearGradient(colors:[Color(white:0.038),Color(white:0.015)],startPoint:.top,endPoint:.bottom))
                .overlay(MidnightMetalSurface(frontFacing:true).clipShape(ChassisFullLowerLipShape()).opacity(0.16).blendMode(.softLight))

            // The approved top shell remains topmost, matching diagnostic
            // compositing and keeping its lower radii in front of the wraps.
            PlinthUpperChamfer()
                .fill(LinearGradient(colors:[.white.opacity(0.10),Color(red:0.38,green:0.31,blue:0.27).opacity(0.07),.clear],startPoint:.top,endPoint:.bottom))

            MidnightPlinthContent(isPlaying:isPlaying,accent:accent)
                .frame(width:w*0.82,height:contentHeight)
                .position(x:w*0.495,y:opticalCenter)
        }
    }}
}

private struct PlinthUpperChamfer: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        p.move(to:c.point(c.seamLeft,in:r)); p.addLine(to:c.point(c.seamRight,in:r))
        p.addQuadCurve(to:c.point(CGPoint(x:0.9485,y:0.791),in:r),control:c.point(CGPoint(x:0.95,y:0.786),in:r))
        p.addLine(to:c.point(CGPoint(x:0.0415,y:0.791),in:r))
        p.addQuadCurve(to:c.point(c.seamLeft,in:r),control:c.point(CGPoint(x:0.04,y:0.786),in:r)); p.closeSubpath()
    }}
}

private struct PlinthLowerWrapLighting: Shape {
    func path(in r:CGRect)->Path { Path { p in
        let c=ChassisOuterContour.self
        p.move(to:c.point(c.faceLowerLeft,in:r)); p.addLine(to:c.point(c.faceLowerRight,in:r))
        p.addCurve(to:c.point(c.lowerRight,in:r),control1:c.point(CGPoint(x:0.943,y:0.881),in:r),control2:c.point(CGPoint(x:0.935,y:0.895),in:r))
        p.addLine(to:c.point(c.lowerLeft,in:r))
        p.addCurve(to:c.point(c.faceLowerLeft,in:r),control1:c.point(CGPoint(x:0.055,y:0.895),in:r),control2:c.point(CGPoint(x:0.047,y:0.881),in:r)); p.closeSubpath()
    }}
}

private struct MidnightFoot: View {
    var body:some View {
        Ellipse().fill(RadialGradient(colors:[Color(white:0.15),Color(white:0.035),.black],center:.top,startRadius:0,endRadius:24))
            .shadow(color:.black.opacity(0.78),radius:3,y:3)
    }
}

private struct MidnightFasciaBrush: View {
    var body:some View { Canvas { context,size in
        var lines=Path()
        stride(from:0.0,through:Double(size.width),by:1.15).forEach { x in
            let offset=midnightNoise(Int(x*10),salt:7.7)*0.55
            lines.move(to:CGPoint(x:x+offset,y:size.height*0.74)); lines.addLine(to:CGPoint(x:x+offset,y:size.height*0.89))
        }
        context.stroke(lines,with:.color(.white.opacity(0.10)),lineWidth:0.22)
    }}
}

private func midnightNoise(_ index:Int,salt:Double)->CGFloat {
    let raw=sin(Double(index)*12.9898+salt*78.233)*43_758.5453
    return CGFloat(raw-floor(raw))
}

private struct MidnightPlinthContent: View {
    let isPlaying:Bool,accent:Color
    var body:some View { GeometryReader { p in
        let h=p.size.height
        HStack(alignment:.center,spacing:0) {
            PlinthBranding()
                .frame(width:p.size.width*0.28,height:h,alignment:.leading)
            Spacer(minLength:p.size.width*0.24)
            HStack(alignment:.center,spacing:p.size.width*0.032) {
                PlinthPower(isPlaying:isPlaying)
                PlinthStartStop()
                PlinthSpeedSelector()
            }
            .frame(height:h)
        }
        .foregroundStyle(Color(red:0.70,green:0.68,blue:0.65).opacity(0.72))
        .shadow(color:.black.opacity(0.70),radius:0.3,y:0.4)
    }}
}

private struct PlinthBranding: View {
    var body:some View { GeometryReader { p in
        VStack(alignment:.leading,spacing:p.size.height*0.055) {
            Text("VINYL").font(.system(size:p.size.height*0.43,weight:.semibold,design:.rounded)).tracking(p.size.height*0.075)
            Text(DeviceInfo.computerName.uppercased())
                .font(.system(size:p.size.height*0.155,weight:.medium,design:.monospaced)).tracking(p.size.height*0.025)
                .lineLimit(1)
        }
        .frame(maxHeight:.infinity,alignment:.center)
    }}
}

private struct MidnightFasciaShape: Shape {
    let depth: CGFloat
    func path(in rect:CGRect)->Path { Path { path in
        let radius=min(rect.width,rect.height)*0.035
        path.move(to:CGPoint(x:radius,y:rect.minY+depth))
        path.addLine(to:CGPoint(x:rect.maxX-radius,y:rect.minY+depth))
        path.addQuadCurve(to:CGPoint(x:rect.maxX,y:rect.minY+depth+radius),control:CGPoint(x:rect.maxX,y:rect.minY+depth))
        path.addLine(to:CGPoint(x:rect.maxX,y:rect.maxY-radius))
        path.addQuadCurve(to:CGPoint(x:rect.maxX-radius,y:rect.maxY),control:CGPoint(x:rect.maxX,y:rect.maxY))
        path.addLine(to:CGPoint(x:radius,y:rect.maxY))
        path.addQuadCurve(to:CGPoint(x:0,y:rect.maxY-radius),control:CGPoint(x:0,y:rect.maxY))
        path.addLine(to:CGPoint(x:0,y:rect.minY+depth+radius))
        path.addQuadCurve(to:CGPoint(x:radius,y:rect.minY+depth),control:CGPoint(x:0,y:rect.minY+depth))
        path.closeSubpath()
    }}
}

private struct MidnightGrain: View {
    var body: some View { Canvas { context,size in
        var bright=Path(), dark=Path()
        for i in 0..<220 {
            let y=CGFloat(i)/220*size.height
            let path = i.isMultiple(of:4) ? bright:dark
            var line=path
            line.move(to:CGPoint(x:0,y:y)); line.addLine(to:CGPoint(x:size.width,y:y+0.15))
            if i.isMultiple(of:4) { bright=line } else { dark=line }
        }
        context.stroke(bright,with:.color(.white.opacity(0.15)),lineWidth:0.32)
        context.stroke(dark,with:.color(.black.opacity(0.20)),lineWidth:0.28)
    }}
}

private struct MidnightTonearm: View {
    let progress:Double, playing:Bool, enabled:Bool, metal:Color, accent:Color
    var body:some View { GeometryReader { p in
        let w=p.size.width,h=p.size.height
        let pivot=CGPoint(x:w*0.60,y:h*0.15)
        let rest=CGPoint(x:w*0.84,y:h*0.43)
        let groove=CGPoint(x:w*(0.10+0.055*progress),y:h*(0.79-0.025*progress))
        let tip=enabled ? groove:rest
        let angle=atan2(tip.y-pivot.y,tip.x-pivot.x) * 180 / .pi
        ZStack {
            // The tube is built from separate shadow, underside, aluminium and
            // highlight strokes so it reads as a round object instead of a bar.
            Canvas { context,_ in
                var arm=Path(); arm.move(to:pivot); arm.addLine(to:tip)
                context.stroke(arm,with:.color(.black.opacity(0.68)),style:StrokeStyle(lineWidth:h*0.030,lineCap:.round))
                var shadow=context; shadow.translateBy(x:h*0.012,y:h*0.018)
                shadow.stroke(arm,with:.color(.black.opacity(0.55)),style:StrokeStyle(lineWidth:h*0.022,lineCap:.round))
                context.stroke(arm,with:.linearGradient(Gradient(colors:[Color(white:0.16),Color(white:0.82),Color(white:0.30)]),startPoint:pivot,endPoint:tip),style:StrokeStyle(lineWidth:h*0.017,lineCap:.round))
                context.stroke(arm,with:.color(.white.opacity(0.42)),style:StrokeStyle(lineWidth:h*0.003,lineCap:.round))
            }

            // Rear counterweight follows the same physical axis as the tube.
            Capsule().fill(LinearGradient(colors:[Color(white:0.78),Color(white:0.24),Color(white:0.035)],startPoint:.top,endPoint:.bottom))
                .frame(width:w*0.145,height:h*0.095)
                .overlay(Capsule().stroke(.white.opacity(0.28),lineWidth:1))
                .rotationEffect(.degrees(angle))
                .position(x:pivot.x-cos(angle * .pi / 180)*w*0.09,y:pivot.y-sin(angle * .pi / 180)*w*0.09)
                .shadow(color:.black.opacity(0.72),radius:5,y:5)

            Ellipse().fill(.black.opacity(0.72)).frame(width:w*0.22,height:h*0.19).position(x:pivot.x,y:pivot.y+h*0.030).blur(radius:3)
            Ellipse().fill(LinearGradient(colors:[Color(white:0.28),Color(white:0.075),Color(white:0.025)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .frame(width:w*0.20,height:h*0.17).position(pivot)
            Ellipse().fill(RadialGradient(colors:[Color(white:0.34),Color(white:0.105),Color(white:0.028)],center:.topLeading,startRadius:1,endRadius:w*0.10))
                .frame(width:w*0.145,height:h*0.122).position(pivot)
            Circle().fill(RadialGradient(colors:[Color(white:0.92),metal,Color(white:0.09)],center:.topLeading,startRadius:1,endRadius:w*0.03))
                .frame(width:w*0.050,height:w*0.050).position(pivot)
                .overlay(Circle().fill(.white.opacity(0.24)).frame(width:w*0.012).position(pivot))

            // Headshell, cartridge and a lifted stylus on pause.
            TaperedHeadshell().fill(LinearGradient(colors:[Color(white:0.34),Color(white:0.075),.black],startPoint:.top,endPoint:.bottom))
                .frame(width:w*0.095,height:h*0.052).rotationEffect(.degrees(angle)).position(tip)
                .shadow(color:.black.opacity(0.65),radius:3,y:3)
            RoundedRectangle(cornerRadius:1).fill(Color(white:0.055)).frame(width:w*0.036,height:h*0.028)
                .rotationEffect(.degrees(angle)).position(x:tip.x,y:tip.y+h*0.020)
            Capsule().fill(Color(white:0.70)).frame(width:1.4,height:h*0.040)
                .position(x:tip.x,y:tip.y+h*(playing ? 0.028:0.018))
                .opacity(enabled ? 1:0.45)

            Capsule().fill(Color(white:0.08)).overlay(Capsule().stroke(.white.opacity(0.18),lineWidth:1))
                .frame(width:w*0.032,height:h*0.13).position(x:w*0.79,y:h*0.40)
        }
        .animation(.easeInOut(duration:enabled ? 1.15:1.55),value:tip)
        .animation(.easeInOut(duration:0.45),value:playing)
    }}
}

private struct TaperedArm: Shape {
    func path(in r:CGRect)->Path { Path { p in
        p.move(to:CGPoint(x:r.midX-r.width*0.35,y:0)); p.addLine(to:CGPoint(x:r.midX+r.width*0.35,y:0));
        p.addLine(to:CGPoint(x:r.midX+r.width*0.19,y:r.maxY)); p.addLine(to:CGPoint(x:r.midX-r.width*0.19,y:r.maxY)); p.closeSubpath()
    }}
}

private struct TaperedHeadshell: Shape {
    func path(in r:CGRect)->Path { Path { p in
        p.move(to:CGPoint(x:r.minX,y:r.height*0.18)); p.addLine(to:CGPoint(x:r.maxX,y:0))
        p.addLine(to:CGPoint(x:r.maxX,y:r.height)); p.addLine(to:CGPoint(x:r.minX,y:r.height*0.78)); p.closeSubpath()
    }}
}

private struct PlinthPower: View {
    let isPlaying:Bool
    var body:some View { GeometryReader { p in
        VStack(spacing:p.size.height*0.06) {
            ZStack {
                Circle().fill(LinearGradient(colors:[Color(white:0.16),Color(white:0.025)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:p.size.height*0.32)
                Circle().fill(Color(red:0.92,green:0.035,blue:0.018)).frame(width:p.size.height*0.17)
                    .shadow(color:.red.opacity(isPlaying ? 0.55:0.16),radius:isPlaying ? 3:1)
            }.opacity(isPlaying ? 1:0.52)
            Text("POWER").font(.system(size:p.size.height*0.14,weight:.medium,design:.monospaced))
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
    }.frame(width:44) }
}

private struct PlinthStartStop: View {
    var body:some View { GeometryReader { p in
        VStack(spacing:p.size.height*0.045) {
            ZStack {
                Circle().fill(.black.opacity(0.58)).frame(width:p.size.height*0.66).offset(y:p.size.height*0.025)
                Circle().fill(RadialGradient(colors:[Color(white:0.76),Color(white:0.31),Color(white:0.075)],center:UnitPoint(x:0.34,y:0.26),startRadius:1,endRadius:p.size.height*0.44)).frame(width:p.size.height*0.60)
                ForEach(0..<3,id:\.self) { ring in Circle().stroke(.white.opacity(0.065-Double(ring)*0.014),lineWidth:0.45).frame(width:p.size.height*(0.52-CGFloat(ring)*0.075)) }
                Capsule().fill(.black.opacity(0.38)).frame(width:1,height:p.size.height*0.34).rotationEffect(.degrees(-42))
            }.shadow(color:.black.opacity(0.62),radius:2,y:1.5)
            Text("START / STOP").font(.system(size:p.size.height*0.14,weight:.medium,design:.monospaced))
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
    }.frame(width:76) }
}

private struct PlinthSpeedSelector: View {
    var body:some View { GeometryReader { p in
        VStack(spacing:p.size.height*0.07) {
            ZStack {
                Capsule().fill(LinearGradient(colors:[Color(white:0.018),Color(white:0.065),Color(white:0.012)],startPoint:.top,endPoint:.bottom)).frame(width:p.size.width*0.92,height:p.size.height*0.34)
                    .shadow(color:.white.opacity(0.09),radius:0.5,y:-0.5)
                Capsule().fill(LinearGradient(colors:[Color(white:0.68),Color(white:0.20),Color(white:0.075)],startPoint:.topLeading,endPoint:.bottomTrailing))
                    .frame(width:p.size.height*0.31,height:p.size.height*0.25).offset(x:-p.size.width*0.20)
                    .shadow(color:.black.opacity(0.75),radius:1.5,y:1)
            }
            Text("33  ·  45").font(.system(size:p.size.height*0.14,weight:.medium,design:.monospaced))
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
    }.frame(width:92) }
}

private struct MidnightEmbeddedDisplay: View {
    let item:PlayingItem
    var body:some View {
        GeometryReader { p in
            HStack(spacing:p.size.height*0.11) {
                artwork.frame(width:p.size.height*0.68,height:p.size.height*0.68)
                    .clipShape(RoundedRectangle(cornerRadius:p.size.height*0.075,style:.continuous))
                VStack(alignment:.leading,spacing:p.size.height*0.055) {
                    Text(item.title).font(.system(size:p.size.height*0.145,weight:.semibold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.72)
                    Text(item.artist).font(.system(size:p.size.height*0.105,weight:.medium)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    if let album=item.collection { Text(album).font(.system(size:p.size.height*0.088)).foregroundStyle(.white.opacity(0.38)).lineLimit(1) }
                    Spacer(minLength:0)
                    if let progress=item.progress {
                        GeometryReader { bar in
                            ZStack(alignment:.leading) {
                                Capsule().fill(.white.opacity(0.13))
                                Capsule().fill(.white.opacity(0.66)).frame(width:bar.size.width*progress)
                            }
                        }.frame(height:2)
                        HStack { Text(time(item.progressMilliseconds)); Spacer(); Text(time(item.durationMilliseconds)) }
                            .font(.system(size:p.size.height*0.075,weight:.medium,design:.monospaced)).foregroundStyle(.white.opacity(0.43))
                    }
                }
            }.padding(p.size.height*0.15)
        }
        .foregroundStyle(Color(red:0.82,green:0.83,blue:0.84).opacity(0.88))
        .background {
            ZStack {
                RoundedRectangle(cornerRadius:20,style:.continuous).fill(Color(white:0.015)).padding(-5)
                    .shadow(color:.black.opacity(0.82),radius:6,y:5)
                RoundedRectangle(cornerRadius:17,style:.continuous)
                    .fill(LinearGradient(colors:[Color(white:0.035),Color(white:0.009)],startPoint:.topLeading,endPoint:.bottomTrailing))
                LinearGradient(colors:[.white.opacity(0.075),.clear,.clear],startPoint:.topLeading,endPoint:.bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius:17,style:.continuous))
                    .blendMode(.screen)
            }
        }
        .accessibilityElement(children:.combine)
        .accessibilityLabel("Now playing \(item.title) by \(item.artist)")
    }
    private func time(_ milliseconds:Int?)->String { let seconds=max(0,(milliseconds ?? 0)/1000); return String(format:"%d:%02d",seconds/60,seconds%60) }
    @ViewBuilder private var artwork:some View {
        if let url=item.artworkURL {
            AsyncImage(url:url) { $0.resizable().scaledToFill() } placeholder:{ Color(white:0.12) }
        } else {
            ZStack { Color(white:0.09); Image(systemName:"music.note").font(.system(size:24,weight:.medium)).foregroundStyle(.white.opacity(0.38)) }
        }
    }
}

private struct DeckShell: View {
    let design: ThemeDesign
    var shape: RoundedRectangle { RoundedRectangle(cornerRadius:design.corner*500,style:.continuous) }
    var body: some View {
        shape.fill(LinearGradient(colors:[design.top,design.bottom],startPoint:.topLeading,endPoint:.bottomTrailing))
            .overlay { if design.wood { Image(design.theme == .gramophone ? "RosewoodTexture":"WalnutTexture").resizable().scaledToFill().blendMode(.softLight).opacity(0.72).clipShape(shape) } }
            .overlay { if design.translucent { shape.fill(.ultraThinMaterial).opacity(0.38) } }
            .overlay { shape.stroke(LinearGradient(colors:[.white.opacity(design.glossy ? 0.48:0.18),.black.opacity(0.42)],startPoint:.top,endPoint:.bottom),lineWidth:design.glossy ? 2:1) }
            .overlay(alignment:.top) { if design.glossy { Capsule().fill(.white.opacity(0.16)).frame(height:2).padding(.horizontal,40).padding(.top,10) } }
    }
}

private struct InternalDetails: View {
    let design: ThemeDesign
    var body: some View { GeometryReader { p in ZStack {
        if design.translucent {
            ForEach(0..<5,id:\.self) { i in Capsule().stroke(design.accent.opacity(0.20),lineWidth:1).frame(width:p.size.width*0.30,height:p.size.height*0.07).position(x:p.size.width*(0.63+CGFloat(i%2)*0.14),y:p.size.height*(0.25+CGFloat(i)*0.12)) }
        }
        if design.silhouette == .console || design.silhouette == .split {
            RoundedRectangle(cornerRadius:5).fill(.black.opacity(0.25)).frame(width:p.size.width*0.17,height:p.size.height*0.72).position(x:p.size.width*0.88,y:p.size.height*0.5)
        }
        if design.theme == .gramophone {
            ForEach(0..<4,id:\.self) { i in RoundedRectangle(cornerRadius:2).stroke(design.metal.opacity(0.32),lineWidth:1).padding(CGFloat(i)*8) }
        }
    }}}
}

private struct ControlCluster: View {
    let design: ThemeDesign, isPlaying: Bool
    var body: some View { GeometryReader { p in
        let w=p.size.width,h=p.size.height
        ZStack {
            if design.theme == .technics {
                Capsule().fill(.black.opacity(0.55)).frame(width:w*0.026,height:h*0.38).position(x:w*0.92,y:h*0.53)
                RoundedRectangle(cornerRadius:3).fill(design.metal).frame(width:w*0.045,height:h*0.045).position(x:w*0.92,y:h*0.53)
                ForEach(0..<9,id:\.self) { i in Rectangle().fill(.black.opacity(0.55)).frame(width:w*0.014,height:1).position(x:w*0.88,y:h*(0.35+CGFloat(i)*0.045)) }
            } else if design.theme == .tokyo || design.theme == .studio {
                ForEach(0..<3,id:\.self) { i in
                    Circle().fill(LinearGradient(colors:[design.metal,.black],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:h*0.075,height:h*0.075).position(x:w*(0.75+CGFloat(i)*0.09),y:h*0.79)
                }
            } else {
                Circle().fill(RadialGradient(colors:[design.metal,.black.opacity(0.8)],center:.topLeading,startRadius:1,endRadius:h*0.045)).frame(width:h*0.065,height:h*0.065).position(x:w*0.90,y:h*0.82)
            }
            Circle().fill(design.accent).frame(width:h*0.014,height:h*0.014).position(x:w*0.84,y:h*0.82).shadow(color:design.accent,radius:isPlaying ? 8:1).opacity(isPlaying ? 0.9:0.25)
        }
    }}
}

private struct RecordView: View {
    let item: PlayingItem, snapshotDate: Date, appearance: AppearanceConfiguration, design: ThemeDesign, reduceMotion: Bool
    @Environment(\.displayRefreshRate) private var displayRefreshRate
    var body: some View { GeometryReader { p in
        let labelDiameter=p.size.width*(design.theme == .midnight ? 0.285:0.255)
        ZStack {
            if design.theme == .midnight {
                Rectangle().fill(.black)
                    .colorEffect(ShaderLibrary.vinylSurface(.float2(p.size.width,p.size.height),.float2(-0.72,-0.64)))
                    .brightness(-0.035)
                    .clipShape(Circle())
            } else {
                Circle().fill(recordColour)
                ForEach(0..<34,id:\.self) { ring in Circle().stroke((ring%6==0 ? Color.white:Color.black).opacity(ring%6==0 ? 0.052:0.24),lineWidth:ring%6==0 ? 0.55:0.35).padding(CGFloat(ring)*p.size.width*0.010+6) }
            }
            if design.theme != .midnight {
                AngularGradient(colors:[.clear,.white.opacity(0.018),.clear,.white.opacity(0.045),.clear,.black.opacity(0.08),.clear],center:.center).clipShape(Circle()).blendMode(.screen)
            }
            TimelineView(.animation(minimumInterval: 1 / max(displayRefreshRate, 1), paused:!item.isPlaying || reduceMotion)) { timeline in
                artwork.clipShape(Circle()).frame(width:labelDiameter,height:labelDiameter)
                    .overlay(Circle().fill(.white.opacity(0.025)).blendMode(.screen))
                    .overlay(Circle().stroke(.white.opacity(0.20),lineWidth:0.8)).shadow(color:.black.opacity(0.55),radius:2,y:1)
                    .rotationEffect(.degrees(rotation(at:timeline.date)))
            }
            Circle().fill(LinearGradient(colors:[.white,Color(white:0.34)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:p.size.width*0.018,height:p.size.width*0.018).shadow(radius:1)
            Circle().stroke(.white.opacity(0.20),lineWidth:1).padding(1)
        }
    } }
    private var recordColour: Color { switch appearance.vinyl { case .white:.init(white:0.84); case .clear:.white.opacity(0.18); case .smoke:.gray.opacity(0.62); case .albumColour:design.accent.opacity(0.72); default:.init(white:0.018) } }
    @ViewBuilder private var artwork: some View { if let url=item.artworkURL { AsyncImage(url:url) { $0.resizable().scaledToFill() } placeholder:{ design.accent } } else { design.accent.overlay { Image(systemName:"music.note").font(.largeTitle) } } }
    private func rotation(at date:Date)->Double { (Double(item.progressMilliseconds ?? 0)/1000 + (item.isPlaying ? max(0,date.timeIntervalSince(snapshotDate)):0))*30 }
}

private struct TonearmView: View {
    let progress: Double, playing: Bool, enabled: Bool, design: ThemeDesign
    var body: some View { GeometryReader { p in
        let angle=(enabled ? -28+progress*18:-28), armWidth=p.size.width*(design.arm == .brass ? 0.095:0.065)
        ZStack(alignment:.top) {
            Circle().fill(RadialGradient(colors:[design.metal,.black],center:.topLeading,startRadius:1,endRadius:p.size.width*0.17)).overlay(Circle().stroke(.white.opacity(0.25),lineWidth:2)).frame(width:p.size.width*0.31)
            Circle().stroke(design.metal.opacity(0.8),lineWidth:p.size.width*0.025).frame(width:p.size.width*0.20).offset(y:p.size.width*0.055)
            Group {
                if design.arm == .sShape {
                    Path { path in path.move(to:CGPoint(x:p.size.width*0.50,y:p.size.width*0.12)); path.addCurve(to:CGPoint(x:p.size.width*0.33,y:p.size.height*0.76),control1:CGPoint(x:p.size.width*0.72,y:p.size.height*0.30),control2:CGPoint(x:p.size.width*0.18,y:p.size.height*0.52)) }.stroke(LinearGradient(colors:[.white,design.metal,.black],startPoint:.leading,endPoint:.trailing),style:StrokeStyle(lineWidth:armWidth,lineCap:.round))
                } else {
                    Capsule().fill(LinearGradient(colors:[.white,design.metal,.black.opacity(0.75)],startPoint:.leading,endPoint:.trailing)).frame(width:armWidth,height:p.size.height*0.69).offset(y:p.size.width*0.13)
                }
            }.overlay(alignment:.bottom) { RoundedRectangle(cornerRadius:3).fill(design.arm == .brass ? design.metal:.black).overlay(Rectangle().fill(design.accent).frame(height:2),alignment:.bottom).frame(width:p.size.width*0.17,height:p.size.height*0.10).offset(y:p.size.height*0.04) }
                .rotationEffect(.degrees(angle),anchor:.top).animation(.easeInOut(duration:playing ? 0.8:1.4),value:angle)
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
    }}
}

private struct NowPlayingPanel: View {
    let item: PlayingItem, style: NowPlayingStyle, design: ThemeDesign, playbackActions: PlaybackActions
    @ViewBuilder var body: some View {
        if design.theme == .midnight {
            ViewThatFits(in:.horizontal) {
                HStack(spacing:22) { cover(size:132); metadata }
                HStack(spacing:14) { cover(size:72); metadata }
            }
            .padding(22).background { panelBackground }.foregroundStyle(.white.opacity(0.92))
            .accessibilityElement(children:.combine).accessibilityLabel("Now playing \(item.title) by \(item.artist)")
        } else {
            HStack(alignment:.center,spacing:design.panel == .rail ? 18:22) {
                if style != .minimal { cover(size:artSize) }
                metadata
            }
            .padding(panelPadding).background { panelBackground }
            .foregroundStyle(design.isLight ? Color.black.opacity(0.82):Color.white.opacity(0.92))
            .accessibilityElement(children:.combine).accessibilityLabel("Now playing \(item.title) by \(item.artist)")
        }
    }

    private var metadata: some View {
        VStack(alignment:.leading,spacing:8) {
                if design.theme != .midnight { Text(design.subtitle).font(.system(size:10,weight:.bold,design:.rounded)).tracking(2.1).foregroundStyle(design.accent) }
                Text(item.title).font(.system(size:style == .floating ? 28:22,weight:.semibold,design:design.panel == .plaque ? .serif:.rounded)).lineLimit(2).minimumScaleFactor(0.78)
                Text(item.artist).font(.system(size:14,weight:.medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                if style == .full, let album=item.collection { Text(album).font(.system(size:12)).foregroundStyle(.tertiary).lineLimit(1) }
                if style != .minimal, let progress=item.progress {
                    GeometryReader { g in ZStack(alignment:.leading) { Capsule().fill(.primary.opacity(0.12)); Capsule().fill(design.theme == .midnight ? .white.opacity(0.72):design.accent).frame(width:g.size.width*progress) } }.frame(height:3).padding(.top,5)
                    HStack { Text(time(item.progressMilliseconds)); Spacer(); Text(time(item.durationMilliseconds)) }.font(.system(size:10,weight:.medium,design:.monospaced)).foregroundStyle(.tertiary)
                }
                if design.theme == .midnight && playbackActions.isAvailable {
                    HStack(spacing:18) {
                        Button(action:{playbackActions.previous?()}) { Image(systemName:"backward.fill").frame(width:42,height:42) }
                        Button(action:{playbackActions.playPause?()}) { Image(systemName:item.isPlaying ? "pause.fill":"play.fill").font(.system(size:18)).frame(width:48,height:48).background(.white.opacity(0.11),in:Circle()) }
                        Button(action:{playbackActions.next?()}) { Image(systemName:"forward.fill").frame(width:42,height:42) }
                    }.buttonStyle(MidnightTransportStyle()).frame(maxWidth:.infinity).padding(.top,5)
                }
        }
    }
    private func cover(size:CGFloat)->some View { artwork.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:14,style:.continuous)).shadow(color:.black.opacity(0.30),radius:12,y:6) }
    private var artSize: CGFloat { design.theme == .midnight ? 132:(style == .floating ? 142:96) }
    private var panelPadding: CGFloat { design.theme == .midnight ? 25:(design.panel == .rail ? 18:24) }
    private func time(_ milliseconds:Int?)->String { let seconds=max(0,(milliseconds ?? 0)/1000); return String(format:"%d:%02d",seconds/60,seconds%60) }
    @ViewBuilder private var panelBackground: some View {
        switch design.panel {
        case .rail: RoundedRectangle(cornerRadius:design.theme == .midnight ? 20:12).fill(design.theme == .midnight ? Color.black.opacity(0.58):design.bottom.opacity(0.86)).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:design.theme == .midnight ? 20:12)).overlay(RoundedRectangle(cornerRadius:design.theme == .midnight ? 20:12).stroke(.white.opacity(0.13),lineWidth:1)).shadow(color:.black.opacity(0.46),radius:22,y:10)
        case .console: RoundedRectangle(cornerRadius:8).fill(design.top.opacity(0.96)).overlay(RoundedRectangle(cornerRadius:8).stroke(design.metal.opacity(0.38),lineWidth:1)).shadow(color:.black.opacity(0.4),radius:20,y:9)
        case .label: RoundedRectangle(cornerRadius:6).fill(design.isLight ? Color.white.opacity(0.78):design.top.opacity(0.88)).shadow(color:.black.opacity(0.2),radius:14,y:7)
        case .plaque: RoundedRectangle(cornerRadius:10).fill(LinearGradient(colors:[design.top,design.bottom],startPoint:.top,endPoint:.bottom)).overlay(RoundedRectangle(cornerRadius:10).stroke(design.metal.opacity(0.55),lineWidth:1)).shadow(color:.black.opacity(0.48),radius:22,y:10)
        case .floating: RoundedRectangle(cornerRadius:30,style:.continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius:30).stroke(.white.opacity(0.22),lineWidth:1)).shadow(color:design.accent.opacity(0.15),radius:28)
        case .glass: RoundedRectangle(cornerRadius:18).fill(.black.opacity(0.44)).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.22),lineWidth:1)).shadow(color:.black.opacity(0.5),radius:24,y:10)
        }
    }
    @ViewBuilder private var artwork: some View { if let url=item.artworkURL { AsyncImage(url:url) { $0.resizable().scaledToFill() } placeholder:{ design.accent } } else { design.accent } }
}

private struct MidnightTransportStyle: ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .contentShape(Circle())
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.58:0.90))
            .background(.white.opacity(configuration.isPressed ? 0.10:0),in:Circle())
            .scaleEffect(configuration.isPressed ? 0.94:1)
            .animation(.easeOut(duration:0.12),value:configuration.isPressed)
    }
}

private struct DisplayIdentification: View {
    let number:Int, name:String
    var body:some View { VStack(spacing:8){Text("\(number)").font(.system(size:96,weight:.bold,design:.rounded));Text(name).font(.title2)}.padding(36).background(.regularMaterial,in:RoundedRectangle(cornerRadius:30)).shadow(radius:30) }
}
