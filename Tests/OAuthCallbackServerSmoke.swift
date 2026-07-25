import Foundation

@main
struct OAuthCallbackServerSmoke {
    static func main() async throws {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        guard PKCE.challenge(for: verifier) == expectedChallenge else {
            throw SmokeError.pkceMismatch
        }

        let server = OAuthCallbackServer()
        let redirectURL = try await server.start()
        guard redirectURL.absoluteString == SpotifyConfiguration.callbackURLString else {
            throw SmokeError.callbackAddress
        }
        let callback = Task {
            try await server.waitForCallback()
        }

        var components = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: "smoke-test-code"),
            URLQueryItem(name: "state", value: "smoke-test-state")
        ]

        let (_, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SmokeError.httpResponse
        }

        let receivedURL = try await callback.value
        let received = URLComponents(url: receivedURL, resolvingAgainstBaseURL: false)?.queryItems
        guard received?.first(where: { $0.name == "code" })?.value == "smoke-test-code",
              received?.first(where: { $0.name == "state" })?.value == "smoke-test-state" else {
            throw SmokeError.callbackMismatch
        }

        print("OAuth callback and PKCE smoke test passed.")
    }
}

private enum SmokeError: Error {
    case pkceMismatch
    case callbackAddress
    case httpResponse
    case callbackMismatch
}
