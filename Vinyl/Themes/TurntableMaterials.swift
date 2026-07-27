import SwiftUI

/// Material data only. Geometry, UV placement, lighting direction and motion
/// belong to the shared renderer and cannot be supplied by a theme.
struct TurntableSurface {
    var colors: [Color]
    var finish: TurntableFinish = .smooth
    /// Multiplies the finished surface RGB, preserving its alpha and shading.
    /// Useful for finishes (such as vinyl) whose base is generated in Metal.
    var tint: Color = .white

    func gradient(from start: UnitPoint, to end: UnitPoint) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: start, endPoint: end)
    }
    var color: Color { colors.first ?? .clear }
}

enum TurntableFinish {
    case smooth
    case brushedMetal(seed: Float)
    case microcement
    case component(kind: Float)
    case vinyl
    /// Static asset, mapped within the receiving surface and clipped to its alpha.
    /// Use a seamless, correctly scaled image; never include lighting or geometry.
    case image(name: String, opacity: Double)
}

struct TurntableMaterials {
    var background: TurntableSurface
    var chassisCore: Color
    var chassisTop: TurntableSurface
    var chassisFront: TurntableSurface
    var platterEdge: TurntableSurface
    var platterRim: TurntableSurface
    var platterMat: TurntableSurface
    var record: TurntableSurface
    var spindle: TurntableSurface
    var feet: TurntableSurface
    var displayHousing: DisplayHousingMaterial
    var tonearm: TonearmMaterial
    var powerHousing: TurntableSurface
    var startStop: TurntableSurface
    var speedSlot: TurntableSurface
    var speedSwitch: TurntableSurface
    var fasciaInk: Color
    var displayInk: Color
    var backgroundWarmLight: Color
    var topWarmLight: Color
    var topCoolLight: Color
    var frontWarmLight: Color
    var chamferWarmLight: Color
    var glassReflection: Color
}

struct DisplayHousingMaterial {
    var walls: [Color]
    var underside: Color
    var bezel: [Color]
    var glass: [Color]
    var finish: TurntableFinish
}

struct TonearmMaterial {
    /// The physical renderer computes the light response of the rotating tube.
    /// Tint changes its material without changing that response or the LED hue.
    var metalTint: SIMD3<Double> = SIMD3(repeating: 1)
    var cartridge: [Color]
    var headshell: [Color]
    var cartridgeBottom: Color
    var headshellEdge: Color
    var finish: TurntableFinish

    func shade(_ luminance: Double) -> Color {
        if metalTint == SIMD3(repeating: 1) { return Color(white: luminance) }
        return Color(red: luminance * metalTint.x,
                     green: luminance * metalTint.y,
                     blue: luminance * metalTint.z)
    }
}

private struct TurntableMaterialsKey: EnvironmentKey {
    static let defaultValue = MidnightMaterials.make()
}

extension EnvironmentValues {
    var turntableMaterials: TurntableMaterials {
        get { self[TurntableMaterialsKey.self] }
        set { self[TurntableMaterialsKey.self] = newValue }
    }
}

/// Applied only to an individual static surface, never the scene/native artwork.
private struct TurntableFinishModifier: ViewModifier {
    let finish: TurntableFinish
    let size: CGSize
    let tint: Color

    @ViewBuilder private func finished(_ content: Content) -> some View {
        switch finish {
        case .smooth: content
        case .brushedMetal(let seed):
            content.colorEffect(ShaderLibrary.brushedMetal(.float2(size.width,size.height),.float(seed)))
        case .microcement:
            content.colorEffect(ShaderLibrary.microcementSurface(.float2(size.width,size.height)))
        case .component(let kind):
            content.colorEffect(ShaderLibrary.componentFinish(.float(kind)))
        case .vinyl:
            content.colorEffect(ShaderLibrary.vinylSurface(.float2(size.width,size.height),.float2(-0.72,-0.64)))
        case .image(let name, let opacity):
            content.overlay {
                Image(name).resizable().scaledToFill()
                    .frame(width:size.width,height:size.height).clipped()
                    .opacity(opacity).mask(content)
            }
        }
    }

    @ViewBuilder func body(content: Content) -> some View {
        if tint == .white { finished(content) }
        else { finished(content).colorMultiply(tint) }
    }
}

extension View {
    func turntableFinish(_ surface: TurntableSurface, size: CGSize) -> some View {
        modifier(TurntableFinishModifier(finish: surface.finish, size: size, tint: surface.tint))
    }
    func turntableFinish(_ finish: TurntableFinish, size: CGSize = .zero) -> some View {
        modifier(TurntableFinishModifier(finish: finish, size: size, tint: .white))
    }
}
