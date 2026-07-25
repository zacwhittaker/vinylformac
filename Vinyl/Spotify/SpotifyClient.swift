import AppKit
import Foundation

final class SpotifyClient {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private var session: StoredSpotifySession?

    init() {
        session = try? SpotifySessionStore.load()
    }

    func isAuthorized(for clientID: String) -> Bool {
        guard let session else { return false }
        return session.clientID == clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func connect(clientID rawClientID: String) async throws {
        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            throw SpotifyError.missingClientID
        }

        let callbackServer = OAuthCallbackServer()
        let redirectURL = try await callbackServer.start()
        let verifier = try PKCE.randomURLSafeString()
        let state = try PKCE.randomURLSafeString(byteCount: 24)

        var authorization = URLComponents(string: "https://accounts.spotify.com/authorize")!
        authorization.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "scope", value: "user-read-currently-playing"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            URLQueryItem(name: "state", value: state)
        ]

        let callbackTask = Task {
            try await callbackServer.waitForCallback()
        }

        guard let authorizationURL = authorization.url,
              NSWorkspace.shared.open(authorizationURL) else {
            callbackServer.stop()
            callbackTask.cancel()
            throw SpotifyError.couldNotOpenBrowser
        }

        let callbackURL = try await callbackTask.value
        let parameters = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let returnedState = parameters.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            throw SpotifyError.authorizationStateMismatch
        }
        if let error = parameters.first(where: { $0.name == "error" })?.value {
            throw SpotifyError.authorizationCancelled(error)
        }
        guard let code = parameters.first(where: { $0.name == "code" })?.value else {
            throw SpotifyError.invalidResponse
        }

        let token = try await requestToken(parameters: [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "code_verifier", value: verifier)
        ])

        guard let refreshToken = token.refreshToken else {
            throw SpotifyError.invalidResponse
        }
        let stored = StoredSpotifySession(
            clientID: clientID,
            accessToken: token.accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(token.expiresIn)),
            scope: token.scope ?? "user-read-currently-playing"
        )
        try SpotifySessionStore.save(stored)
        session = stored
    }

    func disconnect() throws {
        session = nil
        try SpotifySessionStore.delete()
    }

    func fetchCurrentlyPlaying(clientID: String) async throws -> PlayingItem? {
        let accessToken = try await validAccessToken(clientID: clientID)
        return try await fetchCurrentlyPlaying(accessToken: accessToken, clientID: clientID, canRetry: true)
    }

    private func fetchCurrentlyPlaying(
        accessToken: String,
        clientID: String,
        canRetry: Bool
    ) async throws -> PlayingItem? {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        components.queryItems = [
            URLQueryItem(name: "additional_types", value: "track,episode")
        ]
        var request = URLRequest(url: components.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            let payload = try decoder.decode(CurrentlyPlayingPayload.self, from: data)
            return payload.playingItem
        case 204:
            return nil
        case 401 where canRetry:
            guard var current = session else {
                throw SpotifyError.api(status: 401, message: "The session has expired.")
            }
            current.expiresAt = .distantPast
            session = current
            let refreshed = try await validAccessToken(clientID: clientID)
            return try await fetchCurrentlyPlaying(
                accessToken: refreshed,
                clientID: clientID,
                canRetry: false
            )
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw SpotifyError.rateLimited(seconds: retryAfter)
        default:
            throw SpotifyError.api(status: http.statusCode, message: apiMessage(from: data))
        }
    }

    private func validAccessToken(clientID rawClientID: String) async throws -> String {
        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var current = session, current.clientID == clientID else {
            throw SpotifyError.authorizationCancelled("Connect your Spotify account again")
        }
        guard current.needsRefresh else {
            return current.accessToken
        }

        let token = try await requestToken(parameters: [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: current.refreshToken)
        ])

        current.accessToken = token.accessToken
        current.refreshToken = token.refreshToken ?? current.refreshToken
        current.expiresAt = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        current.scope = token.scope ?? current.scope
        try SpotifySessionStore.save(current)
        session = current
        return current.accessToken
    }

    private func requestToken(parameters: [URLQueryItem]) async throws -> SpotifyTokenPayload {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = parameters
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SpotifyError.api(status: http.statusCode, message: apiMessage(from: data))
        }
        return try decoder.decode(SpotifyTokenPayload.self, from: data)
    }

    private func apiMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let description = object["error_description"] as? String {
                return description
            }
            if let message = object["message"] as? String {
                return message
            }
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let error = object["error"] as? String {
                return error
            }
        }
        return HTTPURLResponse.localizedString(forStatusCode: 0)
    }
}

private struct SpotifyTokenPayload: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
}

private struct CurrentlyPlayingPayload: Decodable {
    let isPlaying: Bool
    let progressMs: Int?
    let item: SpotifyItemPayload?

    var playingItem: PlayingItem? {
        guard let item,
              let id = item.id,
              let name = item.name else {
            return nil
        }
        return PlayingItem(
            id: id,
            title: name,
            artist: item.subtitle,
            collection: item.collection,
            artworkURL: item.artworkURL,
            spotifyURL: item.externalUrls?.spotify,
            isPlaying: isPlaying,
            progressMilliseconds: progressMs,
            durationMilliseconds: item.durationMs
        )
    }
}

private struct SpotifyItemPayload: Decodable {
    let id: String?
    let name: String?
    let durationMs: Int?
    let artists: [SpotifyArtistPayload]?
    let album: SpotifyCollectionPayload?
    let show: SpotifyShowPayload?
    let images: [SpotifyImagePayload]?
    let externalUrls: SpotifyExternalURLsPayload?

    var subtitle: String {
        if let artists, !artists.isEmpty {
            return artists.map(\.name).joined(separator: ", ")
        }
        return show?.publisher ?? show?.name ?? "Spotify"
    }

    var collection: String? {
        album?.name ?? show?.name
    }

    var artworkURL: URL? {
        album?.images.first?.url ?? images?.first?.url ?? show?.images.first?.url
    }
}

private struct SpotifyArtistPayload: Decodable {
    let name: String
}

private struct SpotifyCollectionPayload: Decodable {
    let name: String
    let images: [SpotifyImagePayload]
}

private struct SpotifyShowPayload: Decodable {
    let name: String
    let publisher: String?
    let images: [SpotifyImagePayload]
}

private struct SpotifyImagePayload: Decodable {
    let url: URL
}

private struct SpotifyExternalURLsPayload: Decodable {
    let spotify: URL?
}
