import SwiftUI
import ImageIO

/// One download and decoded bitmap per URL, shared across every display.
@MainActor
final class ArtworkImageCache {
    static let shared = ArtworkImageCache()
    private let images = NSCache<NSURL, CGImage>()
    private var pending: [URL: Task<CGImage?, Never>] = [:]

    init() { images.totalCostLimit = 32 * 1024 * 1024 }
    func cached(_ url: URL) -> CGImage? { images.object(forKey: url as NSURL) }

    func image(for url: URL) async -> CGImage? {
        if let image = cached(url) { return image }
        if let task = pending[url] { return await task.value }
        let task = Task.detached(priority: .utility) { () -> CGImage? in
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }
        pending[url] = task
        let image = await task.value
        pending[url] = nil
        if let image { images.setObject(image, forKey: url as NSURL, cost: image.bytesPerRow * image.height) }
        return image
    }
}

/// Preserve the displayed bitmap until a replacement is ready.
struct CachedArtwork<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var displayed: CGImage?

    var body: some View {
        Group {
            if let image = ArtworkImageCache.shared.cached(url) ?? displayed {
                content(Image(decorative: image, scale: 1))
            } else { placeholder() }
        }
        .task(id: url) {
            let image = await ArtworkImageCache.shared.image(for: url)
            guard !Task.isCancelled, let image else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { displayed = image }
        }
    }
}
