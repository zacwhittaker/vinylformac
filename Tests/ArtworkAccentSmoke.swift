import CoreGraphics
import Foundation

@main
struct ArtworkAccentSmoke {
    static func image(background: CGColor, detail: CGColor? = nil, detailWidth: CGFloat = 0) -> CGImage {
        let size = 100
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        if let detail {
            context.setFillColor(detail)
            context.fill(CGRect(x: 0, y: 0, width: detailWidth, height: CGFloat(size)))
        }
        return context.makeImage()!
    }

    static func main() {
        let grayWithTinyTealDetail = image(
            background: CGColor(srgbRed: 0.58, green: 0.58, blue: 0.58, alpha: 1),
            detail: CGColor(srgbRed: 0.05, green: 0.52, blue: 0.56, alpha: 1),
            detailWidth: 3
        )
        let neutral = artworkAccentRGB(grayWithTinyTealDetail)!
        precondition(abs(neutral.x-neutral.y) < 0.001 && abs(neutral.y-neutral.z) < 0.001,
                     "Mostly monochrome artwork inherited a tint: \(neutral)")

        let whiteWithTintedDarkDetail = image(
            background: CGColor(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1),
            detail: CGColor(srgbRed: 0.02, green: 0.18, blue: 0.20, alpha: 1),
            detailWidth: 16
        )
        let whiteAccent = artworkAccentRGB(whiteWithTintedDarkDetail)!
        precondition(abs(whiteAccent.x-whiteAccent.y) < 0.001 && abs(whiteAccent.y-whiteAccent.z) < 0.001,
                     "White artwork inherited a dark-detail tint: \(whiteAccent)")

        let nearBlackWithCyanCast = image(
            background: CGColor(srgbRed: 0.018, green: 0.046, blue: 0.052, alpha: 1)
        )
        let blackAccent = artworkAccentRGB(nearBlackWithCyanCast)!
        precondition(abs(blackAccent.x-blackAccent.y) < 0.001 && abs(blackAccent.y-blackAccent.z) < 0.001,
                     "Near-black artwork amplified a cyan cast: \(blackAccent)")

        let tealWithHighlight = image(
            background: CGColor(srgbRed: 0.08, green: 0.52, blue: 0.56, alpha: 1),
            detail: CGColor(srgbRed: 0.94, green: 0.94, blue: 0.94, alpha: 1),
            detailWidth: 25
        )
        let teal = artworkAccentRGB(tealWithHighlight)!
        precondition(teal.y-teal.x > 0.15 && teal.z-teal.x > 0.15,
                     "Broad teal artwork lost its hue: \(teal)")
        print("Artwork accent passed: gray, white and black covers stay neutral; broad teal stays teal.")
    }
}
