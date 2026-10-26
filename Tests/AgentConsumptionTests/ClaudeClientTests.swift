import ConsumptionKit
import Foundation
import Testing

@testable import AgentConsumption

struct ClaudeClientTests {
    let now = Date(timeIntervalSince1970: 1_791_383_288)
    let secretToken = "sk-test-access-token-123"

    private func client(
        _ session: StubSession, token: DesktopAuth.Token? = nil, failure: Error? = nil
    ) -> ClaudeClient {
        ClaudeClient(
            session: session.session,
            token: { _ in
                if let failure { throw failure }
                return token
            })
    }

    private var signedIn: DesktopAuth.Token {
        DesktopAuth.Token(accessToken: secretToken, expiresAt: now.addingTimeInterval(3_600), plan: "max")
    }

    private let usage =
        #"{"five_hour":{"utilization":37,"resets_at":"2026-10-07T18:00:00Z"},"seven_day":{"utilization":62.5,"resets_at":"2026-10-10T03:00:00Z"}}"#

    @Test func fetchesAndParsesUsageWithTheDesktopToken() async throws {
        let session = StubSession { _ in .json(usage) }
        let result = try await client(session, token: signedIn).fetch(now: now)
        #expect(result.provider == .claude)
        #expect(result.plan == "max")
        #expect(result.session?.usedPercent == 37)
        #expect(result.weekly?.usedPercent == 62.5)
    }

    @Test func sendsABearerRequestWithTheBetaHeaderToTheUsageEndpoint() async throws {
        let session = StubSession { _ in .json(usage) }
        _ = try await client(session, token: signedIn).fetch(now: now)
        let request = try #require(session.requests.first)
        #expect(session.requests.count == 1)
        #expect(request.url == ClaudeClient.usageURL)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(secretToken)")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "agent-consumption")
    }

    @Test func passesTheClockToTheTokenProvider() async throws {
        let seen = LockedBox<Date?>(nil)
        let session = StubSession { _ in .json(usage) }
        let client = ClaudeClient(
            session: session.session,
            token: { date in
                seen.value = date
                return DesktopAuth.Token(accessToken: "t", expiresAt: date.addingTimeInterval(60), plan: nil)
            })
        _ = try await client.fetch(now: now)
        #expect(seen.value == now)
    }

    @Test func noLoginMeansNoRequestAndAnOpenDesktopMessage() async {
        let session = StubSession { _ in .json(usage) }
        await #expect(throws: ProviderError.self) { try await client(session, token: nil).fetch(now: now) }
        #expect(session.requests.isEmpty)
        let message = await message(of: { try await client(session, token: nil).fetch(now: now) })
        #expect(message == ClaudeClient.signInMessage)
    }

    @Test func aKeychainFailureIsReportedAsASignInProblemWithoutLeakingSecrets() async {
        struct Denied: Error {}
        let session = StubSession { _ in .json(usage) }
        let message = await message(of: { try await client(session, failure: Denied()).fetch(now: now) })
        #expect(message.contains("Couldn't read Claude Desktop's login"))
        #expect(message.contains("Allow the prompt"))
        #expect(!message.contains(secretToken))
        #expect(session.requests.isEmpty)
    }

    @Test(arguments: [401, 403])
    func anAuthRejectionMeansOpenDesktop(status: Int) async {
        let session = StubSession { _ in .json(#"{"error":"nope"}"#, status: status) }
        let message = await message(of: { try await client(session, token: signedIn).fetch(now: now) })
        #expect(message == ClaudeClient.signInMessage)
        #expect(!message.contains(secretToken))
    }

    @Test func otherStatusesCarryTheCodeAndAShortBody() async {
        let long = String(repeating: "x", count: 500)
        let session = StubSession { _ in .json(long, status: 503) }
        let message = await message(of: { try await client(session, token: signedIn).fetch(now: now) })
        #expect(message.hasPrefix("HTTP 503: "))
        #expect(message.count < 230)
        #expect(!message.contains(secretToken))
    }

    @Test func anUnparsableBodyIsAnErrorNeverPartialData() async {
        let session = StubSession { _ in .json("<html>not json</html>") }
        await #expect(throws: UsageParseError.self) { try await client(session, token: signedIn).fetch(now: now) }
    }

    @Test func aPayloadWithoutAnyWindowIsRejected() async {
        let session = StubSession { _ in .json(#"{"five_hour":null,"seven_day":null}"#) }
        await #expect(throws: UsageParseError.self) { try await client(session, token: signedIn).fetch(now: now) }
    }

    @Test func aNetworkFailurePropagates() async {
        let session = StubSession { _ in StubSession.Reply(failure: URLError(.notConnectedToInternet)) }
        await #expect(throws: URLError.self) { try await client(session, token: signedIn).fetch(now: now) }
    }

    @Test func enterpriseSpendLimitIsReadAsMonthlyWithDollars() async throws {
        let body =
            #"{"five_hour":null,"seven_day":null,"extra_usage":{"utilization":14.38,"used_credits":60400,"monthly_limit":420000,"currency":"USD","decimal_places":2}}"#
        let session = StubSession { _ in .json(body) }
        let result = try await client(session, token: signedIn).fetch(now: now)
        #expect(result.monthly?.usedPercent == 14.38)
        #expect(result.spend == SpendReading(used: 604, limit: 4200, unit: .usd))
    }

    private func message(of body: () async throws -> ProviderUsage) async -> String {
        do {
            _ = try await body()
            return "no error"
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}

final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value
    init(_ value: Value) { stored = value }
    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
