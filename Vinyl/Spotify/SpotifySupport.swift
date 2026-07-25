import CryptoKit
import Foundation
import Security

enum SpotifyConfiguration {
    static let defaultClientID = "d6d4041a1e644cb4ae4599989802ec29"
    static let callbackPort: UInt16 = 8888
    static let callbackURLString = "http://127.0.0.1:\(callbackPort)/callback"
}

enum SpotifyError: LocalizedError {
    case missingClientID
    case couldNotOpenBrowser
    case authorizationCancelled(String)
    case authorizationStateMismatch
    case callbackFailed(String)
    case invalidResponse
    case api(status: Int, message: String)
    case rateLimited(seconds: Int?)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Add the Client ID from your Spotify developer app first."
        case .couldNotOpenBrowser:
            return "Vinyl could not open the Spotify sign-in page."
        case .authorizationCancelled(let reason):
            return "Spotify sign-in did not complete: \(reason)."
        case .authorizationStateMismatch:
            return "Spotify sign-in returned an invalid state. Please try again."
        case .callbackFailed(let reason):
            return "The local Spotify callback failed: \(reason)."
        case .invalidResponse:
            return "Spotify returned a response Vinyl could not read."
        case .api(let status, let message):
            return "Spotify returned \(status): \(message)"
        case .rateLimited(let seconds):
            if let seconds {
                return "Spotify is rate limiting requests. Try again in \(seconds) seconds."
            }
            return "Spotify is rate limiting requests. Try again shortly."
        case .keychain(let status):
            return "Vinyl could not access Keychain (error \(status))."
        }
    }
}

enum PKCE {
    static func randomURLSafeString(byteCount: Int = 64) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard result == errSecSuccess else {
            throw SpotifyError.keychain(result)
        }
        return Data(bytes).base64URLEncodedString()
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct StoredSpotifySession: Codable {
    let clientID: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var scope: String

    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

enum SpotifySessionStore {
    private static var service: String {
        "\(Bundle.main.bundleIdentifier ?? "Vinyl").spotify"
    }

    private static let account = "oauth-session"

    static func load() throws -> StoredSpotifySession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw SpotifyError.keychain(status)
        }
        return try JSONDecoder().decode(StoredSpotifySession.self, from: data)
    }

    static func save(_ session: StoredSpotifySession) throws {
        let data = try JSONEncoder().encode(session)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addition = base
            addition.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addition as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SpotifyError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw SpotifyError.keychain(updateStatus)
        }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpotifyError.keychain(status)
        }
    }
}
