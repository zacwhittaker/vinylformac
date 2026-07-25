import Foundation
import Network

final class OAuthCallbackServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Vinyl.OAuthCallbackServer")
    private var listener: NWListener?
    private var startContinuation: CheckedContinuation<URL, Error>?
    private var callbackContinuation: CheckedContinuation<URL, Error>?
    private var didFinish = false

    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.startContinuation = continuation
                do {
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(
                        host: NWEndpoint.Host("127.0.0.1"),
                        port: NWEndpoint.Port(rawValue: SpotifyConfiguration.callbackPort)!
                    )

                    let listener = try NWListener(using: parameters)
                    self.listener = listener
                    listener.stateUpdateHandler = { [weak self] state in
                        self?.handle(state: state)
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        self?.handle(connection: connection)
                    }
                    listener.start(queue: self.queue)
                } catch {
                    self.fail(error)
                }
            }
        }
    }

    func waitForCallback() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard !self.didFinish else {
                    continuation.resume(throwing: SpotifyError.callbackFailed("The callback server stopped early."))
                    return
                }
                self.callbackContinuation = continuation
                self.queue.asyncAfter(deadline: .now() + 180) { [weak self] in
                    self?.fail(SpotifyError.callbackFailed("Sign-in timed out."))
                }
            }
        }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
        }
    }

    private func handle(state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port else {
                fail(SpotifyError.callbackFailed("No local port was available."))
                return
            }
            guard port.rawValue == SpotifyConfiguration.callbackPort else {
                fail(SpotifyError.callbackFailed("Spotify callback port \(SpotifyConfiguration.callbackPort) was unavailable."))
                return
            }
            startContinuation?.resume(returning: URL(string: SpotifyConfiguration.callbackURLString)!)
            startContinuation = nil
        case .failed(let error):
            fail(error)
        case .cancelled:
            if !didFinish {
                fail(SpotifyError.callbackFailed("The callback server was cancelled."))
            }
        default:
            break
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                self.sendResponse(on: connection, succeeded: false)
                self.fail(error)
                return
            }
            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let requestLine = request.components(separatedBy: "\r\n").first else {
                self.sendResponse(on: connection, succeeded: false)
                self.fail(SpotifyError.callbackFailed("The browser sent an invalid callback."))
                return
            }

            let parts = requestLine.split(separator: " ")
            guard parts.count >= 2 else {
                self.sendResponse(on: connection, succeeded: false)
                self.fail(SpotifyError.callbackFailed("The callback request was incomplete."))
                return
            }

            let target = String(parts[1])
            let callbackURL = URL(string: target.hasPrefix("http") ? target : "http://127.0.0.1\(target)")
            guard let callbackURL else {
                self.sendResponse(on: connection, succeeded: false)
                self.fail(SpotifyError.callbackFailed("The callback URL was invalid."))
                return
            }

            self.sendResponse(on: connection, succeeded: true)
            self.finish(with: callbackURL)
        }
    }

    private func sendResponse(on connection: NWConnection, succeeded: Bool) {
        let title = succeeded ? "Connected to Spotify" : "Vinyl could not connect"
        let message = succeeded
            ? "You can close this tab and return to Vinyl."
            : "Return to Vinyl and try again."
        let body = """
        <!doctype html>
        <html lang="en">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
        <body style="margin:0;min-height:100vh;display:grid;place-items:center;background:#17151a;color:#fff;font:16px -apple-system,BlinkMacSystemFont,sans-serif">
          <main style="max-width:480px;padding:48px;text-align:center">
            <div style="font-size:48px">●</div>
            <h1>\(title)</h1>
            <p style="color:#c8c2cd">\(message)</p>
          </main>
        </body>
        </html>
        """
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func finish(with url: URL) {
        guard !didFinish else { return }
        didFinish = true
        callbackContinuation?.resume(returning: url)
        callbackContinuation = nil
        listener?.cancel()
        listener = nil
    }

    private func fail(_ error: Error) {
        guard !didFinish else { return }
        didFinish = true
        startContinuation?.resume(throwing: error)
        startContinuation = nil
        callbackContinuation?.resume(throwing: error)
        callbackContinuation = nil
        listener?.cancel()
        listener = nil
    }
}
