import CoreGraphics
import SwiftUI

/// Returns a lighting colour that represents the cover's overall colour.
/// Neutral artwork is decided from the complete image before chromatic pixels
/// are histogrammed, preventing sparse JPEG tint/noise from colouring a
/// genuinely black-and-white cover.
func artworkAccentRGB(_ image: CGImage) -> SIMD3<Double>? {
    let side = 48
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: bytes.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return false }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return true
    }
    guard rendered else { return nil }

    var artworkWeight = 0.0
    var visibleWeight = 0.0
    var chromaWeight = 0.0
    var chromaticAreaWeight = 0.0
    var neutralAreaWeight = 0.0
    var samples: [(hsv: SIMD3<Double>, weight: Double)] = []
    samples.reserveCapacity(side * side)

    for index in stride(from: 0, to: pixels.count, by: 4) {
        let alpha = Double(pixels[index + 3]) / 255
        guard alpha > 0.5 else { continue }
        let rgb = SIMD3<Double>(
            min(1, Double(pixels[index]) / (255 * alpha)),
            min(1, Double(pixels[index + 1]) / (255 * alpha)),
            min(1, Double(pixels[index + 2]) / (255 * alpha))
        )
        let hsv = accentHSV(rgb)
        let chroma = hsv.y * hsv.z
        artworkWeight += alpha
        chromaWeight += chroma * alpha
        if chroma < 0.055 { neutralAreaWeight += alpha }
        if chroma >= 0.07, hsv.y >= 0.16, hsv.z >= 0.10 {
            chromaticAreaWeight += alpha
        }

        // Very dark compression noise can have high mathematical saturation
        // despite carrying no visible colour. Keep it out of hue selection.
        let visibility = min(1, max(0, (hsv.z - 0.04) / 0.32))
        guard visibility > 0 else { continue }
        visibleWeight += visibility
        samples.append((hsv, visibility))
    }

    guard artworkWeight > 0 else { return SIMD3(repeating: 0.88) }
    let averageChroma = chromaWeight / artworkWeight
    let chromaticCoverage = chromaticAreaWeight / artworkWeight
    let neutralCoverage = neutralAreaWeight / artworkWeight

    // Judge monochrome artwork against the complete opaque image, including
    // black pixels. Absolute chroma avoids treating a tiny RGB imbalance in a
    // dark pixel as a strongly saturated colour. A large, clearly coloured
    // region still survives and feeds the existing hue histogram below.
    if averageChroma < 0.035 ||
        chromaticCoverage < 0.08 ||
        (neutralCoverage > 0.80 && chromaticCoverage < 0.20) {
        return SIMD3(repeating: 0.88)
    }

    guard visibleWeight > 0 else { return SIMD3(repeating: 0.88) }

    let hueBins = 48
    var weights = [Double](repeating: 0, count: hueBins)
    var hueVectors = [SIMD2<Double>](repeating: .zero, count: hueBins)
    var saturationSums = [Double](repeating: 0, count: hueBins)
    var valueSums = [Double](repeating: 0, count: hueBins)
    for sample in samples {
        let hsv = sample.hsv
        guard hsv.z > 0.08, hsv.y > 0.10 else { continue }
        let highlightPenalty = 1 - 0.72 * max(0, hsv.z - 0.78) / 0.22
        let weight = pow(hsv.y, 1.28) * pow(hsv.z, 0.72) *
            max(0.28, highlightPenalty) * sample.weight
        let bin = min(hueBins - 1, Int(hsv.x * Double(hueBins)))
        weights[bin] += weight
        hueVectors[bin] += SIMD2(
            cos(hsv.x * 2 * Double.pi),
            sin(hsv.x * 2 * Double.pi)
        ) * weight
        saturationSums[bin] += hsv.y * weight
        valueSums[bin] += hsv.z * weight
    }

    guard let winner = weights.indices.max(by: { weights[$0] < weights[$1] }),
          weights[winner] > 0 else {
        return SIMD3(repeating: 0.88)
    }
    let vector = hueVectors[winner] / weights[winner]
    let hue = vector.x == 0 && vector.y == 0
        ? (Double(winner) + 0.5) / Double(hueBins)
        : (atan2(vector.y, vector.x) / (2 * Double.pi))
            .truncatingRemainder(dividingBy: 1) + (vector.y < 0 ? 1 : 0)
    let sampledSaturation = saturationSums[winner] / weights[winner]
    let sampledValue = valueSums[winner] / weights[winner]
    let saturation = min(0.78, max(0.46, sampledSaturation * 1.45))
    let value = min(0.78, max(0.58, sampledValue * 0.82))
    return accentRGB(hue, saturation, value)
}

func dominantArtworkColor(_ image: CGImage) -> Color? {
    guard let rgb = artworkAccentRGB(image) else { return nil }
    return Color(.sRGB, red: rgb.x, green: rgb.y, blue: rgb.z, opacity: 1)
}

private func accentHSV(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
    let maximum = max(rgb.x, max(rgb.y, rgb.z))
    let minimum = min(rgb.x, min(rgb.y, rgb.z))
    let delta = maximum - minimum
    guard delta > 0.0001 else { return SIMD3(0, 0, maximum) }
    let hue: Double
    if maximum == rgb.x { hue = (rgb.y - rgb.z) / delta }
    else if maximum == rgb.y { hue = 2 + (rgb.z - rgb.x) / delta }
    else { hue = 4 + (rgb.x - rgb.y) / delta }
    return SIMD3(
        (hue / 6).truncatingRemainder(dividingBy: 1) + (hue < 0 ? 1 : 0),
        delta / maximum,
        maximum
    )
}

private func accentRGB(_ hue: Double, _ saturation: Double, _ value: Double) -> SIMD3<Double> {
    let h = (hue - floor(hue)) * 6
    let sector = Int(h)
    let fraction = h - floor(h)
    let p = value * (1 - saturation)
    let q = value * (1 - saturation * fraction)
    let t = value * (1 - saturation * (1 - fraction))
    switch sector {
    case 0: return SIMD3(value, t, p)
    case 1: return SIMD3(q, value, p)
    case 2: return SIMD3(p, value, t)
    case 3: return SIMD3(p, q, value)
    case 4: return SIMD3(t, p, value)
    default: return SIMD3(value, p, q)
    }
}
