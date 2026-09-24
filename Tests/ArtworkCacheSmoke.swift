import Foundation
import ImageIO

final class ArtworkStub: URLProtocol {
    static var requests = 0
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "vinyl.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=")!
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"image/png"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct ArtworkCacheSmoke {
    @MainActor static func main() async {
        precondition(URLProtocol.registerClass(ArtworkStub.self))
        let cache = ArtworkImageCache()
        let url = URL(string: "https://vinyl.test/cover.png")!
        let images = await withTaskGroup(of: CGImage?.self) { group in
            for _ in 0..<20 { group.addTask { await cache.image(for: url) } }
            var results: [CGImage] = []
            for await result in group { if let result { results.append(result) } }
            return results
        }
        precondition(images.count == 20)
        precondition(ArtworkStub.requests == 1, "Concurrent views duplicated downloads")
        precondition(images.allSatisfy { $0 === images[0] }, "Views received different decoded bitmaps")
        for _ in 0..<100 {
            let result = await cache.image(for: url)
            precondition(result === images[0])
        }
        precondition(ArtworkStub.requests == 1, "Cached artwork was downloaded again")
<<<<<<< HEAD
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("vinyl-artwork-smoke-\(UUID().uuidString).png")
        let localData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=")!
        try! localData.write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }
        let localImage = await cache.image(for: localURL)
        precondition(localImage != nil, "Music artwork file did not decode")
        let reusedLocal = await cache.image(for: localURL)
        precondition(localImage === reusedLocal)
        precondition(ArtworkStub.requests == 1, "Local artwork triggered a network request")
=======
>>>>>>> 10bb768fe8843589f7fb9f1375d2e6e8eaec9fb6
        print("Artwork cache passed: 20 concurrent consumers and 100 reuses, one download and one decoded bitmap.")
    }
}
