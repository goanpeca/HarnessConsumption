import ConsumptionKit
import Foundation
import os

/// Fetches Claude plan usage with the OAuth login Claude Code keeps in the Keychain.
///
/// Access tokens last a few hours and Claude Code only refreshes them while it runs, so this client
/// refreshes an expired token itself and writes the rotated tokens back to the same Keychain item,
/// keeping Claude Code signed in.
struct ClaudeClient {
    static let service = "Claude Code-credentials"
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let tokenURLs = [
        URL(string: "https://console.anthropic.com/v1/oauth/token")!,
        URL(string: "https://platform.claude.com/v1/oauth/token")!,
    ]
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    let session: URLSession
    private let log = Logger(subsystem: "com.goanpeca.agentconsumption", category: "claude")

    func fetch(now: Date = .now) async throws -> ProviderUsage {
        var credentials = try loadCredentials()
        if credentials.expiresAt < now.addingTimeInterval(120) {
            credentials = try await refresh(credentials)
        }
        var (data, status) = try await getUsage(token: credentials.accessToken)
        if status == 401 {
            credentials = try await refresh(credentials)
            (data, status) = try await getUsage(token: credentials.accessToken)
        }
        guard status == 200 else {
            throw ProviderError.http(status, String(decoding: data.prefix(200), as: UTF8.self))
        }
        return try ClaudeUsageParser.parse(data, plan: credentials.plan, now: now)
    }

    private func getUsage(token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("agent-consumption", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    // MARK: Credentials

    struct Credentials {
        var root: [String: Any]
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var plan: String?
    }

    private func loadCredentials() throws -> Credentials {
        let raw: String
        do {
            raw = try Keychain.readPassword(service: Self.service)
        } catch {
            throw ProviderError.notSignedIn("Sign in to Claude Code (`claude`) on this Mac.")
        }
        guard let root = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let access = oauth["accessToken"] as? String,
            let refresh = oauth["refreshToken"] as? String
        else {
            throw ProviderError.notSignedIn("Claude Code has no claude.ai login. Run `claude` and /login.")
        }
        let expiresMs = (oauth["expiresAt"] as? NSNumber)?.doubleValue ?? 0
        return Credentials(
            root: root, accessToken: access, refreshToken: refresh,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
            plan: oauth["subscriptionType"] as? String)
    }

    private func refresh(_ old: Credentials) async throws -> Credentials {
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double
        }
        let body = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token", "refresh_token": old.refreshToken, "client_id": Self.clientID,
        ])
        var lastError: Error = ProviderError.notSignedIn("Claude login expired. Run `claude` once.")
        for url in Self.tokenURLs {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200 else {
                    log.notice("token refresh at \(url.host() ?? "", privacy: .public) returned \(status)")
                    lastError = ProviderError.http(status, "token refresh failed; run `claude` once to sign in again")
                    if status == 400 || status == 401 { break }  // refresh token rejected; another host won't help
                    continue
                }
                let token = try JSONDecoder().decode(TokenResponse.self, from: data)
                var updated = old
                updated.accessToken = token.access_token
                updated.refreshToken = token.refresh_token ?? old.refreshToken
                updated.expiresAt = Date().addingTimeInterval(token.expires_in)
                try save(updated)
                log.notice("refreshed Claude token, expires \(updated.expiresAt, privacy: .public)")
                return updated
            } catch let error as ProviderError {
                throw error
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func save(_ credentials: Credentials) throws {
        var root = credentials.root
        var oauth = root["claudeAiOauth"] as? [String: Any] ?? [:]
        oauth["accessToken"] = credentials.accessToken
        oauth["refreshToken"] = credentials.refreshToken
        oauth["expiresAt"] = Int64(credentials.expiresAt.timeIntervalSince1970 * 1000)
        root["claudeAiOauth"] = oauth
        let data = try JSONSerialization.data(withJSONObject: root)
        let account = try Keychain.account(service: Self.service)
        do {
            try Keychain.updatePassword(
                service: Self.service, account: account,
                password: String(decoding: data, as: UTF8.self))
        } catch {
            // The old refresh token is now spent, so Claude Code needs a fresh /login.
            throw ProviderError.notSignedIn(
                "Couldn't save the refreshed Claude token (\(error)). Run `claude` and /login.")
        }
    }
}
