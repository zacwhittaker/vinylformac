import SwiftUI

/// Approved Midnight finish values, lifted verbatim from the physical renderer.
/// New themes copy this value and override surfaces; never mutate this baseline.
enum MidnightMaterials {
    static func make() -> TurntableMaterials {
        TurntableMaterials(
            background: .init(colors:[Color(red:0.062,green:0.058,blue:0.055)],finish:.microcement),
            chassisCore: Color(red:0.070,green:0.064,blue:0.061),
            chassisTop: .init(colors:[Color(red:0.155,green:0.158,blue:0.160),Color(white:0.092),Color(white:0.052)],finish:.brushedMetal(seed:17)),
            chassisFront: .init(colors:[Color(red:0.142,green:0.145,blue:0.147),Color(white:0.086),Color(white:0.050)],finish:.brushedMetal(seed:31)),
            platterEdge: .init(colors:[Color(white:0.40),Color(white:0.19),Color(white:0.055)],finish:.component(kind:2)),
            platterRim: .init(colors:[Color(white:0.20),Color(white:0.10),Color(white:0.038)],finish:.component(kind:1)),
            platterMat: .init(colors:[Color(white:0.035)],finish:.component(kind:1)),
            record: .init(colors:[.black],finish:.vinyl),
            spindle: .init(colors:[Color(white:0.88),Color(white:0.28)],finish:.component(kind:2)),
            feet: .init(colors:[Color(white:0.075),Color(white:0.030),Color(white:0.010)]),
            displayHousing: .init(walls:[Color(white:0.29),Color(white:0.16),Color(white:0.065)],underside:Color(white:0.055),bezel:[Color(white:0.24),Color(white:0.10),Color(white:0.18)],glass:[Color(white:0.045),Color(white:0.012)],finish:.component(kind:0)),
            tonearm: .init(cartridge:[Color(white:0.19),Color(white:0.055),Color(white:0.026)],headshell:[Color(white:0.28),Color(white:0.095),Color(white:0.035)],cartridgeBottom:Color(white:0.025),headshellEdge:Color(white:0.075),finish:.component(kind:0)),
            powerHousing: .init(colors:[Color(white:0.16),Color(white:0.025)],finish:.component(kind:0)),
            startStop: .init(colors:[Color(white:0.64),Color(white:0.32),Color(white:0.095)],finish:.component(kind:2)),
            speedSlot: .init(colors:[Color(white:0.018),Color(white:0.065),Color(white:0.012)],finish:.component(kind:1)),
            speedSwitch: .init(colors:[Color(white:0.68),Color(white:0.20),Color(white:0.075)],finish:.component(kind:2)),
            fasciaInk: Color(red:0.70,green:0.68,blue:0.65).opacity(0.72),
            displayInk: Color(red:0.82,green:0.83,blue:0.84).opacity(0.88),
            backgroundWarmLight: Color(red:0.50,green:0.34,blue:0.22),
            topWarmLight: Color(red:0.96,green:0.88,blue:0.75),
            topCoolLight: Color(red:0.70,green:0.76,blue:0.82),
            frontWarmLight: Color(red:0.72,green:0.55,blue:0.43),
            chamferWarmLight: Color(red:0.38,green:0.31,blue:0.27),
            glassReflection: .white
        )
    }
}
