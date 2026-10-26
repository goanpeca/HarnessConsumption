import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

struct CodexClientTests {
    let now = Date(timeIntervalSince1970: 1_791_383_288)
    let secretToken = "codex-test-access-token-456"

    private func auth(_ sandbox: Sandbox, account: String? = "acct-1", token: String? = nil) throws -> URL {
        let account = account.map { #","account_id":"\#($0)""# } ?? ""
        return try sandbox.write(
            #"{"auth_mode":"chatgpt","tokens":{"access_token":"\#(token ?? secretToken)"\#(account)}}"#, to: "auth.json"
        )
    }

    private let usage =
        #"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":12,"limit_window_seconds":604800,"reset_at":1791985929}}}"#

    private func message(of body: () async throws -> ProviderUsage) async -> String {
        do {
            _ = try await body()
            return "no error"
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    @Test func fetchesAndParsesUsage() async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json(usage) }
        let client = CodexClient(session: session.session, authFile: try auth(sandbox))
        let result = try await client.fetch(now: now)
        #expect(result.provider == .codex)
        #expect(result.plan == "pro")
        #expect(result.weekly?.usedPercent == 12)
    }

    @Test func sendsTheTokenAccountAndUserAgentToTheUsageEndpoint() async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json(usage) }
        _ = try await CodexClient(session: session.session, authFile: try auth(sandbox)).fetch(now: now)
        let request = try #require(session.requests.first)
        #expect(session.requests.count == 1)
        #expect(request.url == CodexClient.usageURL)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(secretToken)")
        #expect(request.value(forHTTPHeaderField: "chatgpt-account-id") == "acct-1")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "codex_cli_rs")
    }

    @Test func theAccountHeaderIsOmittedWhenTheLoginHasNoAccount() async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json(usage) }
        _ = try await CodexClient(session: session.session, authFile: try auth(sandbox, account: nil)).fetch(now: now)
        #expect(session.requests.first?.value(forHTTPHeaderField: "chatgpt-account-id") == nil)
    }

    @Test func aMissingOrUnusableLoginMeansOpenTheDesktopAppAndNoRequest() async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json(usage) }
        let missing = CodexClient(
            session: session.session, authFile: sandbox.directory.appendingPathComponent("nope.json"))
        let noTokens = CodexClient(
            session: session.session, authFile: try sandbox.write(#"{"auth_mode":"apikey"}"#, to: "a.json"))
        let garbage = CodexClient(session: session.session, authFile: try sandbox.write("not json", to: "b.json"))
        for client in [missing, noTokens, garbage] {
            let text = await message(of: { try await client.fetch(now: now) })
            #expect(text.contains("ChatGPT/Codex desktop app"))
        }
        #expect(session.requests.isEmpty)
    }

    @Test(arguments: [401, 403])
    func anAuthRejectionMeansOpenTheDesktopApp(status: Int) async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json("{}", status: status) }
        let client = CodexClient(session: session.session, authFile: try auth(sandbox))
        let text = await message(of: { try await client.fetch(now: now) })
        #expect(text.contains("Codex login expired"))
        #expect(!text.contains(secretToken))
    }

    @Test func otherStatusesCarryTheCodeAndAShortBody() async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json(String(repeating: "y", count: 500), status: 500) }
        let client = CodexClient(session: session.session, authFile: try auth(sandbox))
        let text = await message(of: { try await client.fetch(now: now) })
        #expect(text.hasPrefix("HTTP 500: "))
        #expect(text.count < 230)
    }

    @Test func aBusinessAccountWithoutRateLimitsReadsItsSpendLimit() async throws {
        let sandbox = Sandbox()
        let body =
            #"{"plan_type":"business","rate_limit":null,"spend_control":{"individual_limit":{"limit":"42858","used":"1903.5","used_percent":4,"reset_at":1793491200}}}"#
        let session = StubSession { _ in .json(body) }
        let result = try await CodexClient(session: session.session, authFile: try auth(sandbox)).fetch(now: now)
        #expect(result.monthly?.usedPercent == 4)
        #expect(result.spend == SpendReading(used: 1903.5, limit: 42_858, unit: .credits))
    }

    @Test func anUnparsableBodyIsAnError() async throws {
        let sandbox = Sandbox()
        let session = StubSession { _ in .json("nope") }
        let client = CodexClient(session: session.session, authFile: try auth(sandbox))
        await #expect(throws: UsageParseError.self) { try await client.fetch(now: now) }
    }

    @Test func theAuthFileLivesUnderCodexHomeWhenSet() {
        let home = URL(fileURLWithPath: "/fake/home")
        #expect(
            CodexClient.authFile(environment: ["CODEX_HOME": "/custom/codex"], home: home).path
                == "/custom/codex/auth.json")
        #expect(CodexClient.authFile(environment: [:], home: home).path == "/fake/home/.codex/auth.json")
        #expect(CodexClient.authFile(environment: ["CODEX_HOME": ""], home: home).path == "/fake/home/.codex/auth.json")
    }

    @Test func providerErrorsDescribeThemselves() {
        #expect(ProviderError.notSignedIn("hello").errorDescription == "hello")
        #expect(ProviderError.http(418, "teapot").errorDescription == "HTTP 418: teapot")
    }
}
