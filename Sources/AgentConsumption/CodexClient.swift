import ConsumptionKit
import Foundation

/// Fetches Codex plan usage with the ChatGPT login the Codex desktop app keeps in `~/.codex/auth.json`.
///
/// It never refreshes the token: the desktop app refreshes it whenever it runs, and rotating it here
/// could sign Codex out.
struct CodexClient: Sendable {
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    let session: URLSession
    var authFile: URL = Self.defaultAuthFile

    static var defaultAuthFile: URL { authFile() }

    /// `$CODEX_HOME/auth.json`, or `~/.codex/auth.json` when it isn't set (or is empty).
    static func authFile(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let codexHome = environment["CODEX_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        return (codexHome ?? home.appendingPathComponent(".codex")).appendingPathComponent("auth.json")
    }

    func fetch(now: Date = .now) async throws -> ProviderUsage {
        struct Auth: Decodable {
            struct Tokens: Decodable {
                let access_token: String
                let account_id: String?
            }

            let auth_mode: String?
            let tokens: Tokens?
        }
        guard let data = try? Data(contentsOf: authFile),
            let auth = try? JSONDecoder().decode(Auth.self, from: data), let tokens = auth.tokens
        else {
            throw ProviderError.notSignedIn("Open the ChatGPT/Codex desktop app and sign in, then Refresh.")
        }
        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(tokens.access_token)", forHTTPHeaderField: "Authorization")
        if let account = tokens.account_id {
            request.setValue(account, forHTTPHeaderField: "chatgpt-account-id")
        }
        request.setValue("codex_cli_rs", forHTTPHeaderField: "User-Agent")
        let (body, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 {
            throw ProviderError.notSignedIn("Codex login expired. Open the ChatGPT/Codex desktop app, then Refresh.")
        }
        guard status == 200 else {
            throw ProviderError.http(status, String(decoding: body.prefix(200), as: UTF8.self))
        }
        return try CodexUsageParser.parse(body, now: now)
    }
}

enum ProviderError: Error, LocalizedError {
    case notSignedIn(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case let .notSignedIn(message): message
        case let .http(status, body): "HTTP \(status): \(body)"
        }
    }
}
