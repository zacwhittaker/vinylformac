import SwiftUI
import CoreGraphics

private struct ArtworkAccentKey: EnvironmentKey {
    static let defaultValue = Color(white:0.88)
}

private extension EnvironmentValues {
    var artworkAccent: Color {
        get { self[ArtworkAccentKey.self] }
        set { self[ArtworkAccentKey.self] = newValue }
    }
}

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
    var restoresPlaybackState = false

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var artworkAccent = Color(white:0.88)

    var body: some View {
        GeometryReader { proxy in
            let design = ThemeDesign(theme: appearance.rendererTheme, seed: item.id)
            let layout = WallpaperLayout(size: proxy.size, mode: appearance.layout, design: design)
            ZStack {
                ThemeBackground(item: item, appearance: appearance, design: design)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
                if design.theme == .midnight {
                    SharedTurntableScene(
                        item:item,snapshotDate:snapshotDate,appearance:appearance,
                        animation:animation,design:design,playbackActions:playbackActions,
                        reduceMotion:systemReduceMotion || animation.reduceMotionOverride,
                        scale:layout.midnightCamera.scale,
                        restoresPlaybackState:restoresPlaybackState
                    )
                    .position(layout.midnightCamera.center)
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
                    NowPlayingPanel(item: item, snapshotDate: snapshotDate, style: appearance.nowPlaying, design: design, playbackActions: playbackActions)
                        .scaleEffect(appearance.nowPlayingScale)
                        .opacity(appearance.nowPlayingOpacity * (item.isPlaying ? 1 : 0.72))
                        .frame(width: layout.infoWidth)
                        .position(layout.infoCenter)
                }
                if let identificationNumber {
                    DisplayIdentification(number: identificationNumber, name: displayName ?? "Display")
                }
            }
            // Native animation layers must not be captured by a SwiftUI shader.
            // A static alpha overlay adjusts exposure without a full-screen pass.
            .overlay {
                (sceneExposure < 0 ? Color.black : Color.white)
                    .opacity(min(0.45, abs(sceneExposure) * 0.22))
                    .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: transitionDuration), value: item.id)
            .animation(.easeInOut(duration: 0.55), value: appearance)
            .frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }.ignoresSafeArea()
        .environment(\.artworkAccent,artworkAccent)
        .environment(\.turntableMaterials,appearance.turntableTheme.materials)
        .task(id:item.artworkURL) {
            guard let url=item.artworkURL else { artworkAccent=Color(white:0.88); return }
            let image=await ArtworkImageCache.shared.image(for:url)
            guard !Task.isCancelled else { return }
            artworkAccent=image.flatMap(dominantArtworkColor) ?? Color(white:0.88)
        }
    }

    private var transitionDuration: Double {
        if systemReduceMotion || animation.reduceMotionOverride { return 0.15 }
        return switch animation.style { case .minimal: 0.2; case .smooth: 0.75 / animation.speed; case .physical: 1.6 / animation.speed }
    }
}

/// Every material theme uses Midnight’s approved physical base in this immutable logical coordinate space.
/// The wrapper itself changes size, while the scene's internal proposal never
/// changes, avoiding monitor-dependent GeometryReader recomputation.
private struct SharedTurntableScene: View {
    static let designSize = CGSize(width:1920,height:1000)
    let item:PlayingItem, snapshotDate:Date, appearance:AppearanceConfiguration
    let animation:AnimationConfiguration, design:ThemeDesign
    let playbackActions:PlaybackActions
    let reduceMotion:Bool, scale:CGFloat
    let restoresPlaybackState:Bool
    var body:some View {
        Color.clear
            .frame(width:Self.designSize.width*scale,height:Self.designSize.height*scale)
            .overlay {
                MidnightDeck(item:item,snapshotDate:snapshotDate,appearance:appearance,
                             animation:animation,design:design,playbackActions:playbackActions,
                             reduceMotion:reduceMotion,
                             restoresPlaybackState:restoresPlaybackState)
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
    private static let midnightDesignSize = SharedTurntableScene.designSize
    var portrait: Bool { size.height > size.width }

    /// Camera framing for the immutable Midnight scene. The scene is never
    /// re-authored per display: portrait layouts simply choose a larger lens
    /// and translate the same scene inside a clipped viewport.
    var midnightCamera: MidnightCameraFrame {
        guard design.theme == .midnight else {
            return MidnightCameraFrame(scale: 1, center: deckCenter)
        }
        return MidnightCameraFrame(size: size)
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

private struct MidnightCameraFrame {
    let scale: CGFloat
    let center: CGPoint

    init(scale: CGFloat, center: CGPoint) {
        self.scale = scale
        self.center = center
    }

    init(size: CGSize) {
        let designSize = SharedTurntableScene.designSize
        let aspect = size.width / max(size.height, 1)
        let fitScale = min(size.width * 0.94 / designSize.width,
                           size.height * 0.88 / designSize.height)

        // Keep the established aspect-fit composition in wide layouts. The
        // narrow band adds only a restrained crop before portrait framing
        // takes over, avoiding a discontinuity around square windows.
        let narrowT = Self.smoothStep(from: 1.45, to: 0.98, value: aspect)
        let narrowScale = fitScale * (1 + 0.12 * narrowT)

        // In portrait, the record's authored center is the left camera
        // anchor. Solve the lens from that anchor to the chassis' right edge
        // so a deliberate strip of empty background always remains visible.
        // This is the same relationship as the green guide in the reference:
        // screen-Y is down and the scene's x coordinates are design-space.
        let diskCenterX = designSize.width * 0.345
        let chassisRightX = designSize.width * 0.95
        // Portrait displays use the screen edge itself as the disk-center
        // guide. Keep this at zero; even a small inset is visibly wrong when
        // the spindle is the alignment reference.
        let leftDiskInset: CGFloat = 0
        let rightGap = max(24, size.width * 0.10)
        let widthFramedScale = max(0.01, (size.width - rightGap - leftDiskInset) /
                                   max(1, chassisRightX - diskCenterX))
        // The height guard avoids applying camera cropping to tiny utility
        // windows, while the aspect-ratio rule remains the primary trigger
        // for all normal vertical displays.
        let portraitT = size.height >= 900
            ? Self.smoothStep(from: 0.98, to: 0.76, value: aspect)
            : 0
        scale = narrowScale + (widthFramedScale - narrowScale) * portraitT

        // Move the scene so the record center lands on the left inset. The
        // right edge then lands at width - rightGap by construction.
        let portraitCenterX = leftDiskInset - (diskCenterX - designSize.width * 0.5) * scale
        let horizontalT = portraitT
        let centerX = size.width * 0.5 + (portraitCenterX - size.width * 0.5) * horizontalT

        // Bottom anchoring is part of the camera, not the authored scene.
        // The small inset respects the wallpaper viewport while keeping the
        // feet/plinth close to the lower edge in portrait mode.
        let portraitCenterY = size.height * 0.965 - designSize.height * scale * 0.5
        let verticalT = portraitT
        let centerY = size.height * 0.53 + (portraitCenterY - size.height * 0.53) * verticalT
        center = CGPoint(x: centerX, y: centerY)
    }

    private static func smoothStep(from high: CGFloat, to low: CGFloat, value: CGFloat) -> CGFloat {
        guard high != low else { return value <= low ? 1 : 0 }
        let t = min(1, max(0, (high - value) / (high - low)))
        return t * t * (3 - 2 * t)
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
                CachedArtwork(url:url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
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

/// A smooth warm-charcoal studio surface separates the cooler graphite deck
/// from its surroundings, including on displays with lifted black levels.
private struct MidnightStudioDesk: View {
    @Environment(\.turntableMaterials) private var materials
    var body:some View {
        GeometryReader { proxy in
            let w=proxy.size.width,h=proxy.size.height
            ZStack {
                MidnightMicrocementSurface()
                RadialGradient(colors:[materials.backgroundWarmLight.opacity(0.08),.clear],center:UnitPoint(x:0.10,y:0.13),startRadius:0,endRadius:max(w,h)*0.72)
                RadialGradient(colors:[.white.opacity(0.022),.clear],center:UnitPoint(x:0.48,y:0.55),startRadius:0,endRadius:max(w,h)*0.50)
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

private struct MidnightMicrocementSurface: View {
    @Environment(\.turntableMaterials) private var materials
    var body:some View { GeometryReader { proxy in
        Rectangle()
            .fill(materials.background.color)
            .turntableFinish(materials.background,size:proxy.size)
    }.ignoresSafeArea() }
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
    @Environment(\.turntableMaterials) private var materials
    let item: PlayingItem, snapshotDate: Date, appearance: AppearanceConfiguration, animation: AnimationConfiguration, design: ThemeDesign
    let playbackActions: PlaybackActions
    let reduceMotion: Bool
    var restoresPlaybackState = false
    @Environment(\.artworkAccent) private var artworkAccent
    @State private var playbackMechanismActive = false
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
            MidnightUnderglow(color:artworkAccent)
                .modifier(PhysicalPlaneProjection(plane:.topDeck))
            ZStack {
                // Rear supports are occluded by the deck at this camera angle.
                ForEach([0.14,0.85],id:\.self) { x in
                    MidnightFoot().frame(width:w*0.044,height:h*0.024)
                        .position(x:w*x,y:h*0.17)
                }
                ForEach([0.12,0.87],id:\.self) { x in
                    MidnightFoot().frame(width:w*0.052,height:h*0.030)
                        .position(x:w*x,y:h*0.900)
                }
            }.modifier(PhysicalPlaneProjection(plane:.topDeck))

            // A single master enclosure underlies both visible planes. The
            // derived surface/face paths meet on the same contour seam.
            ChassisDiagnosticBlueShape()
                .fill(materials.chassisCore)
                .shadow(color:.black.opacity(0.62),radius:3,y:3)
                .modifier(PhysicalPlaneProjection(plane:.topDeck))

            ZStack {
                MidnightPlinth(isPlaying:item.isPlaying,accent:design.accent)
            }
            .modifier(PhysicalPlaneProjection(plane:.frontPlinth))

            ZStack {
                MidnightTopShape()
                    .fill(materials.chassisTop.gradient(from:.topLeading,to:.bottomTrailing))
                    .turntableFinish(materials.chassisTop,size:p.size)
                    .shadow(color:.black.opacity(0.48),radius:2,y:2)
                RadialGradient(colors:[materials.topWarmLight.opacity(0.075),.clear],center:UnitPoint(x:0.08,y:0.10),startRadius:0,endRadius:w*0.62)
                    .clipShape(MidnightTopShape()).blendMode(.screen)
                LinearGradient(colors:[.clear,materials.topCoolLight.opacity(0.055)],startPoint:.leading,endPoint:.trailing)
                    .clipShape(MidnightTopShape()).blendMode(.screen)

            // Platter: diffuse album-reactive LED bed, grounded contact
            // shadow, thick graphite rim, machined edge and top mat. The
            // colour fills the shadow volume rather than tracing its edge.
                Ellipse().fill(.black.opacity(0.78))
                    .frame(width:d*1.14,height:d*0.90)
                    .position(x:center.x,y:center.y+h*0.050)
                    .blur(radius:7)
                Ellipse().fill(
                    RadialGradient(colors:[
                        artworkAccent.opacity(appearance.platterGlow ? appearance.lightingIntensity*0.42 : 0),
                        artworkAccent.opacity(appearance.platterGlow ? appearance.lightingIntensity*0.22 : 0),
                        .clear
                    ],center:.center,startRadius:d*0.06,endRadius:d*0.72)
                )
                    .frame(width:d*1.28,height:d*1.02)
                    .position(x:center.x,y:center.y+h*0.050)
                    .blur(radius:d*0.035)
                Ellipse().fill(artworkAccent.opacity(appearance.platterGlow ? appearance.lightingIntensity*0.24 : 0))
                    .frame(width:d*1.11,height:d*0.87)
                    .position(x:center.x,y:center.y+h*0.045)
                    .blur(radius:d*0.020)
                Ellipse().fill(materials.platterEdge.gradient(from:.topLeading,to:.bottomTrailing))
                    .turntableFinish(materials.platterEdge,size:CGSize(width:d,height:d))
                    .frame(width:d*1.105,height:d*0.875).position(x:center.x,y:center.y+h*0.031)
                Ellipse().fill(materials.platterRim.gradient(from:.topLeading,to:.bottomTrailing))
                    .turntableFinish(materials.platterRim,size:CGSize(width:d,height:d))
                    .frame(width:d*1.075,height:d*0.84).position(x:center.x,y:center.y+h*0.016)
                ForEach(0..<3,id:\.self) { ring in
                    Ellipse().stroke(.white.opacity(0.075-Double(ring)*0.018),lineWidth:0.55)
                        .frame(width:d*(1.064-CGFloat(ring)*0.012),height:d*(0.829-CGFloat(ring)*0.010))
                        .position(x:center.x,y:center.y+h*0.015)
                }
                Ellipse().fill(materials.platterMat.color)
                    .turntableFinish(materials.platterMat,size:CGSize(width:d,height:d))
                    .frame(width:d*1.035,height:d*0.805).position(center)
                // The disc shadow is static. Including the rotating image in
                // this blur would require rebuilding a large shadow each frame.
                Circle().fill(.black).frame(width:d*0.98,height:d*0.98).scaleEffect(y:0.76)
                    .position(x:center.x,y:center.y-h*0.004)
                    .shadow(color:.black.opacity(0.75),radius:5,y:5)
                    .shadow(color:design.accent.opacity(appearance.platterGlow ? appearance.lightingIntensity*0.24:0),radius:d*0.10)
            RecordView(item:item,snapshotDate:snapshotDate,appearance:appearance,design:design,
                       reduceMotion:reduceMotion,isSpinning:playbackMechanismActive)
                .frame(width:d*0.98,height:d*0.98).scaleEffect(y:0.76)
                .position(x:center.x,y:center.y-h*0.004)
                .transition(.offset(y:-18).combined(with:.opacity))

                MidnightTonearm(progress:item.progress ?? 0,playing:item.isPlaying,
                    enabled:animation.tonearmMovement && item.id != PlayingItem.idle.id,
                    reduceMotion:reduceMotion,
                    recordSurface:CGRect(x:center.x-d*0.49,y:center.y-h*0.004-d*0.49*0.76,
                                         width:d*0.98,height:d*0.98*0.76),
                    accent:artworkAccent,
                    itemID:item.id,
                    positionMilliseconds:item.progressMilliseconds,
                    durationMilliseconds:item.durationMilliseconds,
                    sampledAt:item.sampledAt,
                    idleDelay:animation.idleDelay,
                    restoresPlaybackState:restoresPlaybackState,
                    onPlaybackMechanismChanged:{ playbackMechanismActive = $0 })
                    .zIndex(1) // The complete assembly stays above the display throughout its swing.
                if appearance.nowPlaying != .hidden {
                    let cardWidth = w * 0.275
                    let cardHeight = cardWidth * 250 / 910
                    let cardY = h * 0.555
                    // Balance the clearance across the card's full height,
                    // using the platter ellipse and the chassis' straight edge.
                    let nearestY = max(cardY-cardHeight/2, center.y+h*0.031)
                    let ellipseY = (nearestY-center.y-h*0.031)/(d*0.875/2)
                    let platterRight = center.x+d*1.105/2*sqrt(max(0,1-ellipseY*ellipseY))
                    let edge = ChassisOuterContour.self
                    let edgeT = (cardY/h-edge.backRight.y)/(edge.rightFront.y-edge.backRight.y)
                    let deckRight = w*(edge.backRight.x+edgeT*(edge.rightFront.x-edge.backRight.x))
                    MidnightEmbeddedDisplay(item:item,snapshotDate:snapshotDate,
                                             progressAdvancing:playbackMechanismActive)
                        .frame(width:cardWidth,height:cardHeight)
                        .position(x:(platterRight+deckRight)/2,y:cardY)
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
    @Environment(\.turntableMaterials) private var materials
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
                    colors:materials.chassisFront.colors,
                    startPoint:.top,endPoint:.bottom
                ))
                .turntableFinish(materials.chassisFront,size:p.size)
                .overlay(RadialGradient(colors:[.white.opacity(0.045),.clear],center:UnitPoint(x:0.50,y:0.81),startRadius:0,endRadius:w*0.48).clipShape(ChassisDiagnosticBlueShape()).blendMode(.screen))
                .overlay(LinearGradient(colors:[materials.frontWarmLight.opacity(0.055),.white.opacity(0.025),.black.opacity(0.16)],startPoint:.leading,endPoint:.trailing).clipShape(ChassisDiagnosticBlueShape()).blendMode(.softLight))
                .shadow(color:.black.opacity(0.40),radius:h*0.008,y:h*0.004)


            // The approved top shell remains topmost, matching diagnostic
            // compositing and keeping its lower radii in front of the wraps.
            PlinthUpperChamfer()
                .fill(LinearGradient(colors:[.white.opacity(0.10),materials.chamferWarmLight.opacity(0.07),.clear],startPoint:.top,endPoint:.bottom))

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

/// Diffuse spill from a concealed album-colour perimeter strip. Drawn behind
/// the enclosure and feet so neither the emitter nor light covers the fascia.
private struct MidnightUnderglow: View {
    let color: Color
    var body:some View { GeometryReader { p in
        let w=p.size.width,h=p.size.height
        let perimeter=Path { path in
            path.move(to:CGPoint(x:w*0.105,y:h*0.12))
            path.addLine(to:CGPoint(x:w*0.055,y:h*0.851))
            path.addQuadCurve(to:CGPoint(x:w*0.09,y:h*0.893),control:CGPoint(x:w*0.055,y:h*0.893))
            path.addLine(to:CGPoint(x:w*0.90,y:h*0.893))
            path.addQuadCurve(to:CGPoint(x:w*0.935,y:h*0.851),control:CGPoint(x:w*0.935,y:h*0.893))
            path.addLine(to:CGPoint(x:w*0.905,y:h*0.12))
            path.closeSubpath()
        }
        ZStack {
            perimeter.stroke(color.opacity(0.28),lineWidth:h*0.028)
                .blur(radius:h*0.020)
            perimeter.stroke(color.opacity(0.42),lineWidth:h*0.008)
                .blur(radius:h*0.006)
        }
    }.allowsHitTesting(false) }
}

private struct MidnightFoot: View {
    @Environment(\.turntableMaterials) private var materials
    var body:some View { GeometryReader { p in
        let shape=RoundedRectangle(cornerRadius:min(p.size.width,p.size.height)*0.24,style:.continuous)
        ZStack {
            // A low-contrast, directional finish gives the support the
            // compressed, matte appearance of moulded rubber.
            shape.fill(materials.feet.gradient(from:.topLeading,to:.bottomTrailing))
                .turntableFinish(materials.feet,size:p.size)
            Canvas(opaque:false,rendersAsynchronously:true) { context,size in
                var texture=Path()
                stride(from:-size.height,to:size.width+size.height,by:2.4).forEach { offset in
                    texture.move(to:CGPoint(x:offset,y:0))
                    texture.addLine(to:CGPoint(x:offset-size.height,y:size.height))
                }
                context.stroke(texture,with:.color(.white.opacity(0.055)),lineWidth:0.28)
            }
            .clipShape(shape)
            shape.strokeBorder(LinearGradient(colors:[.white.opacity(0.12),.black.opacity(0.55)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.55)
            Capsule().fill(.white.opacity(0.055))
                .frame(width:p.size.width*0.58,height:max(0.7,p.size.height*0.10))
                .position(x:p.size.width*0.50,y:p.size.height*0.22)
                .blur(radius:0.35)
        }
        .shadow(color:.black.opacity(0.88),radius:3,y:2)
        .shadow(color:.black.opacity(0.45),radius:0.5,y:-0.5)
    }}
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
    @Environment(\.turntableMaterials) private var materials
    let isPlaying:Bool,accent:Color
    var body:some View { GeometryReader { p in
        let h=p.size.height
        HStack(alignment:.center,spacing:0) {
            PlinthBranding()
                .frame(width:p.size.width*0.28,height:h,alignment:.leading)
            Spacer(minLength:p.size.width*0.24)
            HStack(alignment:.center,spacing:p.size.width*0.032) {
            PlinthPower(isOn:true)
                PlinthStartStop()
                PlinthSpeedSelector()
            }
            .frame(height:h)
        }
        .foregroundStyle(materials.fasciaInk)
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
    @Environment(\.turntableMaterials) private var materials
    let isOn:Bool
    var body:some View { GeometryReader { p in
        VStack(spacing:p.size.height*0.06) {
            ZStack {
                Circle().fill(materials.powerHousing.gradient(from:.topLeading,to:.bottomTrailing))
                    .turntableFinish(materials.powerHousing,size:p.size).frame(width:p.size.height*0.32)
                Circle().fill(.red.opacity(isOn ? 0.22:0.06))
                    .frame(width:p.size.height*0.28)
                    .blur(radius:p.size.height*0.065)
                Circle().fill(RadialGradient(colors:[
                    .white.opacity(isOn ? 0.92:0.35),
                    Color(red:1,green:0.13,blue:0.055).opacity(isOn ? 0.98:0.30),
                    Color(red:0.58,green:0.008,blue:0.002).opacity(isOn ? 0.92:0.22),
                    .clear
                ],center:UnitPoint(x:0.30,y:0.25),startRadius:0,endRadius:p.size.height*0.105))
                    .frame(width:p.size.height*0.18)
                    .overlay(Circle().stroke(Color(red:1,green:0.12,blue:0.04).opacity(isOn ? 0.92:0.25),lineWidth:max(0.6,p.size.height*0.012)))
                Circle().fill(.white.opacity(isOn ? 0.72:0.20))
                    .frame(width:p.size.height*0.035)
                    .offset(x:-p.size.height*0.035,y:-p.size.height*0.040)
                    .blur(radius:0.25)
            }.opacity(isOn ? 1:0.52)
            Text("POWER").font(.system(size:p.size.height*0.14,weight:.medium,design:.monospaced))
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
    }.frame(width:44) }
}

private struct PlinthStartStop: View {
    @Environment(\.turntableMaterials) private var materials
    var body:some View { GeometryReader { p in
        VStack(spacing:p.size.height*0.045) {
            ZStack {
                Circle().fill(.black.opacity(0.58)).frame(width:p.size.height*0.66).offset(y:p.size.height*0.025)
                Circle().fill(RadialGradient(colors:materials.startStop.colors,center:UnitPoint(x:0.34,y:0.26),startRadius:1,endRadius:p.size.height*0.44))
                    .turntableFinish(materials.startStop,size:p.size).frame(width:p.size.height*0.60)
                ForEach(0..<3,id:\.self) { ring in Circle().stroke(.white.opacity(0.065-Double(ring)*0.014),lineWidth:0.45).frame(width:p.size.height*(0.52-CGFloat(ring)*0.075)) }
                Capsule().fill(.black.opacity(0.38)).frame(width:1,height:p.size.height*0.34).rotationEffect(.degrees(-42))
            }.shadow(color:.black.opacity(0.62),radius:2,y:1.5)
            Text("START / STOP").font(.system(size:p.size.height*0.14,weight:.medium,design:.monospaced))
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
    }.frame(width:76) }
}

private struct PlinthSpeedSelector: View {
    @Environment(\.turntableMaterials) private var materials
    var body:some View { GeometryReader { p in
        VStack(spacing:p.size.height*0.07) {
            ZStack {
                Capsule().fill(materials.speedSlot.gradient(from:.top,to:.bottom)).frame(width:p.size.width*0.92,height:p.size.height*0.34)
                    .turntableFinish(materials.speedSlot,size:p.size)
                    .shadow(color:.white.opacity(0.09),radius:0.5,y:-0.5)
                Capsule().fill(materials.speedSwitch.gradient(from:.topLeading,to:.bottomTrailing))
                    .turntableFinish(materials.speedSwitch,size:p.size)
                    .frame(width:p.size.height*0.31,height:p.size.height*0.25).offset(x:-p.size.width*0.20)
                    .shadow(color:.black.opacity(0.75),radius:1.5,y:1)
            }
            Text("33  ·  45").font(.system(size:p.size.height*0.14,weight:.medium,design:.monospaced))
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
    }.frame(width:92) }
}

/// Exact approved diagnostic: 910x250 face, 20-unit mirrored wedges,
/// and a 30-unit continuous shadow. A is the local origin.
private struct DisplayHousingGeometry {
    let width: CGFloat
    var scale: CGFloat { width / 910 }
    var faceHeight: CGFloat { 250 * scale }
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x:x*scale, y:y*scale)
    }
    func polygon(_ vertices: [CGPoint]) -> Path {
        Path { path in
            guard let first = vertices.first else { return }
            path.move(to:first)
            for vertex in vertices.dropFirst() { path.addLine(to:vertex) }
            path.closeSubpath()
        }
    }
    var face: Path { polygon([point(0,0),point(910,0),point(910,250),point(0,250)]) }
    // A shallow rounded bezel sits on the approved housing. All four
    // corners reuse the same cubic profile, reflected about the centre.
    func bezel(inset: CGFloat = 0, drop: CGFloat = 0) -> Path {
        let r: CGFloat = 250 * 0.075 - inset // Same radius as the artwork.
        let k: CGFloat = 0.5522847498307936
        let l = inset, t = inset+drop, b = 250-inset+drop, right: CGFloat = 910-inset
        return Path { p in
            p.move(to:point(l+r,t)); p.addLine(to:point(right-r,t))
            p.addCurve(to:point(right,t+r),control1:point(right-r+k*r,t),control2:point(right,t+r-k*r))
            p.addLine(to:point(right,b-r))
            p.addCurve(to:point(right-r,b),control1:point(right,b-r+k*r),control2:point(right-r+k*r,b))
            p.addLine(to:point(l+r,b))
            p.addCurve(to:point(l,b-r),control1:point(l+r-k*r,b),control2:point(l,b-r+k*r))
            p.addLine(to:point(l,t+r))
            p.addCurve(to:point(l+r,t),control1:point(l,t+r-k*r),control2:point(l+r-k*r,t))
            p.closeSubpath()
        }
    }
    var left: Path { polygon([point(0,0),point(0,250),point(-20,162)]) }
    var right: Path { left.applying(CGAffineTransform(a:-1,b:0,c:0,d:1,tx:width,ty:0)) }
    var shadow: Path {
        // 1 -> 2 -> 3 -> 8 -> 6 -> 7 -> 5 -> 4
        polygon([point(-20,162),point(0,250),point(910,250),point(930,162),
                 point(930,192),point(910,280),point(0,280),point(-20,192)])
    }
}

private struct MidnightEmbeddedDisplay: View {
    @Environment(\.turntableMaterials) private var materials
    @Environment(\.artworkAccent) private var artworkAccent
    let item: PlayingItem
    let snapshotDate: Date
    let progressAdvancing: Bool
    var body: some View {
        GeometryReader { proxy in
            let geometry = DisplayHousingGeometry(width:proxy.size.width)
            let overflow = geometry.scale * 30
            ZStack(alignment:.topLeading) {
                Canvas { context, _ in
                    // Reserve real drawing space for wedges outside the face.
                    context.translateBy(x:overflow,y:overflow)
                    context.fill(geometry.shadow, with:.linearGradient(
                        Gradient(colors:[.black.opacity(0.82),.black.opacity(0.38)]),
                        startPoint:geometry.point(0,250),endPoint:geometry.point(0,280)))
                    for wall in [geometry.left, geometry.right] {
                        context.fill(wall, with:.linearGradient(
                            Gradient(colors:materials.displayHousing.walls),
                            startPoint:.zero,endPoint:geometry.point(0,250)))
                    }
                    context.fill(geometry.bezel(drop:4),with:.color(materials.displayHousing.underside))
                    context.fill(geometry.bezel(),with:.linearGradient(
                        Gradient(colors:materials.displayHousing.bezel),
                        startPoint:.zero,endPoint:geometry.point(0,250)))
                    context.fill(geometry.bezel(inset:5), with:.linearGradient(
                        Gradient(colors:materials.displayHousing.glass),
                        startPoint:.zero,endPoint:geometry.point(910,250)))
                    context.stroke(geometry.bezel(),with:.color(.white.opacity(0.13)),lineWidth:0.65)
                }
                .turntableFinish(materials.displayHousing.finish,size:proxy.size)
                .padding(-overflow)
                geometry.bezel(inset:3)
                    .stroke(artworkAccent.opacity(0.34),lineWidth:4.6*geometry.scale)
                    .blur(radius:5.5*geometry.scale)
                geometry.bezel(inset:3)
                    .stroke(artworkAccent.opacity(0.98),lineWidth:1.8*geometry.scale)
                    .shadow(color:artworkAccent.opacity(0.92),radius:4.5*geometry.scale)
                    .shadow(color:artworkAccent.opacity(0.58),radius:13*geometry.scale)
                    .allowsHitTesting(false)
                MidnightDisplayFace(item:item,snapshotDate:snapshotDate,
                                    progressAdvancing:progressAdvancing)
                    .frame(width:proxy.size.width,height:geometry.faceHeight)
                    .overlay {
                        // A broad, restrained reflection reads as smoked glass
                        // without adding grain over artwork or text.
                        geometry.bezel(inset:6)
                            .fill(LinearGradient(stops:[.init(color:materials.glassReflection.opacity(0.085),location:0),.init(color:materials.glassReflection.opacity(0.028),location:0.32),.init(color:materials.glassReflection.opacity(0.006),location:0.48),.init(color:.clear,location:0.68)],startPoint:.topLeading,endPoint:.bottomTrailing))
                            .allowsHitTesting(false)
                    }
            }
        }
    }
}

private struct MidnightDisplayFace: View {
    @Environment(\.turntableMaterials) private var materials
    @Environment(\.artworkAccent) private var artworkAccent
    @Environment(\.playbackRenderingSuspended) private var suspended
    let item:PlayingItem
    let snapshotDate:Date
    let progressAdvancing:Bool
    var body:some View {
        GeometryReader { p in
            HStack(spacing:p.size.height*0.11) {
                artwork.frame(width:p.size.height*0.68,height:p.size.height*0.68)
                    .clipShape(RoundedRectangle(cornerRadius:p.size.height*0.075,style:.continuous))
                    .overlay(RoundedRectangle(cornerRadius:p.size.height*0.075,style:.continuous).strokeBorder(LinearGradient(colors:[.white.opacity(0.19),.black.opacity(0.65)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.6))
                    .shadow(color:.black.opacity(0.75),radius:p.size.height*0.018,y:p.size.height*0.012)
                VStack(alignment:.leading,spacing:p.size.height*0.055) {
                    Text(item.title).font(.system(size:p.size.height*0.145,weight:.semibold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.72)
                    Text(item.artist).font(.system(size:p.size.height*0.105,weight:.medium)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    if let album=item.collection { Text(album).font(.system(size:p.size.height*0.088)).foregroundStyle(.white.opacity(0.38)).lineLimit(1) }
                    Spacer(minLength:0)
                    if item.progress != nil {
                        TimelineView(PlaybackTextSchedule(item:item,paused:suspended)) { timeline in
                            let progressMilliseconds=currentProgress(at:timeline.date)
                            VStack(spacing:p.size.height*0.045) {
                                PlaybackProgressBar(item:item,color:artworkAccent,showsIndicator:true,
                                                    isAdvancing:progressAdvancing).frame(height:10)
                                HStack { Text(time(progressMilliseconds)); Spacer(); Text(time(item.durationMilliseconds)) }
                                    .font(.system(size:p.size.height*0.075,weight:.medium,design:.monospaced)).foregroundStyle(.white.opacity(0.43))
                            }
                        }
                    }
                }
            }.padding(p.size.height*0.15)
        }
        .foregroundStyle(materials.displayInk)
        .accessibilityElement(children:.combine)
        .accessibilityLabel("Now playing \(item.title) by \(item.artist)")
    }
    private func time(_ milliseconds:Int?)->String { let seconds=max(0,(milliseconds ?? 0)/1000); return String(format:"%d:%02d",seconds/60,seconds%60) }
    private func currentProgress(at date:Date)->Int {
        return item.positionMilliseconds()
    }
    @ViewBuilder private var artwork:some View {
        if let url=item.artworkURL {
            CachedArtwork(url:url) { $0.resizable().scaledToFill() } placeholder:{ Color(white:0.12) }
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
    @Environment(\.turntableMaterials) private var materials
    let item: PlayingItem, snapshotDate: Date, appearance: AppearanceConfiguration, design: ThemeDesign, reduceMotion: Bool
    var isSpinning: Bool? = nil
    @Environment(\.artworkAccent) private var artworkAccent
    var body: some View { GeometryReader { p in
        let labelDiameter=p.size.width*(design.theme == .midnight ? 0.285:0.255)
        ZStack {
            if design.theme == .midnight {
                Rectangle().fill(materials.record.color)
                    .turntableFinish(materials.record,size:p.size)
                    .brightness(-0.035)
                    .clipShape(Circle())
                // Keep the album colour present without washing out the black
                // base; the shader and fine circular texture should remain
                // visible between the reflected grooves.
                Circle().fill(
                    RadialGradient(colors:[artworkAccent.opacity(0.09), .clear],
                                   center:UnitPoint(x:0.30,y:0.22),
                                   startRadius:0,endRadius:p.size.width*0.63)
                ).blendMode(.screen).clipShape(Circle())
                RecordWaveAccents(color:artworkAccent)
                    .clipShape(Circle())
                Circle().stroke(artworkAccent.opacity(0.95),lineWidth:max(1.0,p.size.width*0.005))
                    .shadow(color:artworkAccent.opacity(0.95),radius:p.size.width*0.018)
                    .shadow(color:artworkAccent.opacity(0.60),radius:p.size.width*0.045)
                    .shadow(color:artworkAccent.opacity(0.38),radius:p.size.width*0.085)
                // A narrow clear-coat reflection follows the existing lamp axis.
                // Its annular mask keeps the centre label and black dead wax clear.
                Circle().fill(AngularGradient(stops:[
                    .init(color:.clear,location:0),
                    .init(color:.clear,location:0.095),
                    .init(color:.white.opacity(0.14),location:0.116),
                    .init(color:.clear,location:0.137),
                    .init(color:.clear,location:0.582),
                    .init(color:.white.opacity(0.20),location:0.616),
                    .init(color:.clear,location:0.650),
                    .init(color:.clear,location:1)
                ],center:.center))
                    .mask(Circle().stroke(lineWidth:p.size.width*0.28).padding(p.size.width*0.17))
                    .blendMode(.screen)
                // Allow the outer bloom to spill onto the platter.
                // A very restrained highlight sells the polished surface
                // without turning the black vinyl into a grey disk.
                Ellipse().fill(
                    LinearGradient(colors:[.white.opacity(0.14),.clear],startPoint:.leading,endPoint:.trailing)
                ).frame(width:p.size.width*0.52,height:p.size.height*0.15)
                    .rotationEffect(.degrees(-18)).offset(x:-p.size.width*0.20,y:-p.size.height*0.22)
                    .blur(radius:p.size.width*0.018).blendMode(.screen)
                    .clipShape(Circle())
                Circle().stroke(.white.opacity(0.20),lineWidth:max(0.6,p.size.width*0.0018)).padding(p.size.width*0.012)
            } else {
                Circle().fill(recordColour)
                ForEach(0..<34,id:\.self) { ring in Circle().stroke((ring%6==0 ? Color.white:Color.black).opacity(ring%6==0 ? 0.052:0.24),lineWidth:ring%6==0 ? 0.55:0.35).padding(CGFloat(ring)*p.size.width*0.010+6) }
            }
            if design.theme != .midnight {
                AngularGradient(colors:[.clear,.white.opacity(0.018),.clear,.white.opacity(0.045),.clear,.black.opacity(0.08),.clear],center:.center).clipShape(Circle()).blendMode(.screen)
            }
            SpinningArtwork(url:item.artworkURL, startingAngle:rotation(at:snapshotDate),
                            isPlaying:(isSpinning ?? item.isPlaying) && !reduceMotion, fallback:design.accent)
            .frame(width:labelDiameter,height:labelDiameter)
            Circle().fill(materials.spindle.gradient(from:.topLeading,to:.bottomTrailing))
                .turntableFinish(materials.spindle,size:p.size)
                .frame(width:p.size.width*0.018,height:p.size.width*0.018).shadow(radius:1)
            Circle().stroke(.white.opacity(0.20),lineWidth:1).padding(1)
        }
    } }
    private var recordColour: Color { switch appearance.vinyl { case .white:.init(white:0.84); case .clear:.white.opacity(0.18); case .smoke:.gray.opacity(0.62); case .albumColour:design.accent.opacity(0.72); default:.init(white:0.018) } }
    @ViewBuilder private var artwork: some View { if let url=item.artworkURL { CachedArtwork(url:url) { $0.resizable().scaledToFill() } placeholder:{ design.accent } } else { design.accent.overlay { Image(systemName:"music.note").font(.largeTitle) } } }
    private func rotation(at date:Date)->Double { (Double(item.progressMilliseconds ?? 0)/1000 + (item.isPlaying ? max(0,date.timeIntervalSince(snapshotDate)):0))*30 }
}

/// Exact concentric circles share the record's perspective projection.
private struct RecordWaveAccents: View {
    let color: Color
    var body: some View {
        ZStack {
            // Let the black material and shader texture carry the image;
            // colour is reserved for a soft reflected trace in the grooves.
            waveShapes(lineWidth:7).opacity(0.20).blur(radius:13)
            waveShapes(lineWidth:4.2).opacity(0.30).blur(radius:5)
            waveShapes(lineWidth:1.2).opacity(0.32)
        }
        .blendMode(.screen)
    }
    private func waveShapes(lineWidth:CGFloat) -> some View {
        ZStack {
            ForEach(0..<18,id:\.self) { row in
                RecordWavePath(row:row)
                    .stroke(AngularGradient(colors:[color.opacity(0.10),color.opacity(0.42),color.opacity(0.14),color.opacity(0.32),color.opacity(0.10)],center:.center),style:StrokeStyle(lineWidth:lineWidth,lineCap:.round,lineJoin:.round))
            }
        }
    }
}

private struct RecordWavePath: Shape {
    let row: Int
    func path(in rect:CGRect) -> Path {
        let radius=min(rect.width,rect.height)*0.5
        let center=CGPoint(x:rect.midX,y:rect.midY)
        let ringRadius:CGFloat = 0.36+CGFloat(row)*0.034
        let r=ringRadius*radius
        return Path(ellipseIn:CGRect(x:center.x-r,y:center.y-r,width:r*2,height:r*2))
    }
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
    @Environment(\.playbackRenderingSuspended) private var suspended
    let item: PlayingItem, snapshotDate: Date, style: NowPlayingStyle, design: ThemeDesign, playbackActions: PlaybackActions
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
                if style != .minimal, item.progress != nil {
                    TimelineView(PlaybackTextSchedule(item:item,paused:suspended)) { timeline in
                        let progressMilliseconds=currentProgress(at:timeline.date)
                        VStack(spacing:8) {
                            PlaybackProgressBar(item:item,color:design.theme == .midnight ? .white.opacity(0.72):design.accent).frame(height:3).padding(.top,5)
                            HStack { Text(time(progressMilliseconds)); Spacer(); Text(time(item.durationMilliseconds)) }.font(.system(size:10,weight:.medium,design:.monospaced)).foregroundStyle(.tertiary)
                        }
                    }
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
    private func currentProgress(at date:Date)->Int {
        return item.positionMilliseconds()
    }
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
    @ViewBuilder private var artwork: some View { if let url=item.artworkURL { CachedArtwork(url:url) { $0.resizable().scaledToFill() } placeholder:{ design.accent } } else { design.accent } }
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
