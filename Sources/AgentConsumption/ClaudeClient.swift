import ConsumptionKit
import Foundation

/// Fetches Claude plan usage with the login Claude Desktop keeps in its own config.
///
/// It never refreshes the token: Claude Desktop refreshes it while it runs, and rotating it here
/// could sign Desktop out.
struct ClaudeClient: Sendable {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let signInMessage = "Open Claude Desktop and sign in, then Refresh."

    let session: URLSession
    var token: @Sendable (Date) throws -> DesktopAuth.Token? = { try DesktopAuth.claudeToken(now: $0) }

    func fetch(now: Date = .now) async throws -> ProviderUsage {
        let token: DesktopAuth.Token?
        do {
            token = try self.token(now)
        } catch {
            throw ProviderError.notSignedIn("Couldn't read Claude Desktop's login (\(error)). Allow the prompt.")
        }
        guard let token else { throw ProviderError.notSignedIn(Self.signInMessage) }
        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("agent-consumption", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw ProviderError.notSignedIn(Self.signInMessage) }
        guard status == 200 else {
            throw ProviderError.http(status, String(decoding: data.prefix(200), as: UTF8.self))
        }
        return try ClaudeUsageParser.parse(data, plan: token.plan, now: now)
    }
}
