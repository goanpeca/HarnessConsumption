import Foundation
import Testing

@testable import AgentConsumption

struct DesktopAuthTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let secret = "unit-test-secret"

    /// Produced outside this code base with Python's PBKDF2 and OpenSSL AES-128-CBC (salt `saltysalt`,
    /// 1003 rounds, IV of 16 spaces) from the secret above, so it checks the real parameters.
    let goldenBlob =
        "djEwN0McR2JBf1ixnXNRwD2hFhps8byItWN+DE1lT+UuSWdZH8QreVOCA8haKj8NLfcjUmZL1MqALYBJuCbet8akievkJlk483I6dNoh21wHm5blQdcr4gNICXJ3QME37jvk"

    // MARK: decrypt

    @Test func decryptsAnIndependentlyProducedBlob() throws {
        let plain = try DesktopAuth.decrypt(#require(Data(base64Encoded: goldenBlob)), secret: secret)
        let text = String(decoding: plain, as: UTF8.self)
        #expect(text.contains("golden-token"))
    }

    @Test func decryptRoundTripsWhateverWeSeal() throws {
        let plain = Data(#"{"k":"v"}"#.utf8)
        #expect(try DesktopAuth.decrypt(Seal.encrypt(plain, secret: "another"), secret: "another") == plain)
    }

    @Test func aWrongSecretDoesNotYieldThePlaintext() throws {
        let sealed = try #require(Data(base64Encoded: goldenBlob))
        let wrong = try? DesktopAuth.decrypt(sealed, secret: "not-the-secret")
        #expect(wrong == nil || !String(decoding: wrong ?? Data(), as: UTF8.self).contains("golden-token"))
    }

    @Test func rejectsAnUnknownFormatPrefix() {
        #expect(throws: (any Error).self) { try DesktopAuth.decrypt(Data("v11xxxxxxxxxxxxxxxx".utf8), secret: secret) }
        #expect(throws: (any Error).self) { try DesktopAuth.decrypt(Data(), secret: secret) }
    }

    @Test func rejectsCorruptCiphertext() {
        let corrupt = Data("v10".utf8) + Data(repeating: 7, count: 10)
        #expect(throws: (any Error).self) { try DesktopAuth.decrypt(corrupt, secret: secret) }
    }

    // MARK: choosing the token

    private func token(_ cache: [String: [String: Any]]) throws -> DesktopAuth.Token? {
        let sandbox = Sandbox()
        let file = try sandbox.write(Seal.config(cache: cache, secret: secret), to: "config.json")
        return try DesktopAuth.claudeToken(now: now, configFile: file, secret: { secret })
    }

    @Test func readsTheTokenAndPlanFromAGoldenConfig() throws {
        let sandbox = Sandbox()
        let file = try sandbox.write(#"{"oauth:tokenCacheV2":"\#(goldenBlob)"}"#, to: "config.json")
        let token = try #require(try DesktopAuth.claudeToken(now: now, configFile: file, secret: { secret }))
        #expect(token.accessToken == "golden-token")
        #expect(token.plan == "pro")
        #expect(token.expiresAt == Date(timeIntervalSince1970: 4_102_444_800))
    }

    @Test func prefersTheLongestLivedUnexpiredToken() throws {
        let picked = try token([
            "short": Seal.entry(token: "short", expiresAt: now.addingTimeInterval(60)),
            "long": Seal.entry(token: "long", expiresAt: now.addingTimeInterval(86_400)),
            "mid": Seal.entry(token: "mid", expiresAt: now.addingTimeInterval(3_600)),
        ])
        #expect(picked?.accessToken == "long")
    }

    @Test func skipsExpiredTokensAndReturnsNilWhenNoneRemain() throws {
        let mixed = try token([
            "old": Seal.entry(token: "old", expiresAt: now.addingTimeInterval(-1)),
            "ok": Seal.entry(token: "ok", expiresAt: now.addingTimeInterval(1)),
        ])
        #expect(mixed?.accessToken == "ok")
        #expect(try token(["old": Seal.entry(token: "old", expiresAt: now.addingTimeInterval(-3_600))]) == nil)
        #expect(try token([:]) == nil)
    }

    @Test func atTheExpiryInstantTheTokenIsAlreadyUnusable() throws {
        #expect(try token(["edge": Seal.entry(token: "edge", expiresAt: now)]) == nil)
    }

    @Test func ignoresEntriesMissingATokenOrExpiry() throws {
        let picked = try token([
            "no-token": ["expiresAt": Int64(now.timeIntervalSince1970 * 1000) + 60_000],
            "no-expiry": ["token": "x"],
            "good": Seal.entry(token: "good", expiresAt: now.addingTimeInterval(60), plan: nil),
        ])
        #expect(picked?.accessToken == "good")
        #expect(picked?.plan == nil)
    }

    @Test func returnsNilWhenDesktopIsNotSignedIn() throws {
        let sandbox = Sandbox()
        #expect(
            try DesktopAuth.claudeToken(
                now: now, configFile: sandbox.directory.appendingPathComponent("none.json"), secret: { secret }) == nil)
        let noCache = try sandbox.write("{}", to: "empty.json")
        #expect(try DesktopAuth.claudeToken(now: now, configFile: noCache, secret: { secret }) == nil)
        let notBase64 = try sandbox.write(#"{"oauth:tokenCacheV2":"%%%"}"#, to: "bad.json")
        #expect(try DesktopAuth.claudeToken(now: now, configFile: notBase64, secret: { secret }) == nil)
    }

    @Test func doesNotAskForTheKeychainSecretWhenThereIsNothingToDecrypt() throws {
        let sandbox = Sandbox()
        let noCache = try sandbox.write("{}", to: "empty.json")
        struct Asked: Error {}
        #expect(try DesktopAuth.claudeToken(now: now, configFile: noCache, secret: { throw Asked() }) == nil)
    }

    @Test func surfacesAKeychainFailure() throws {
        let sandbox = Sandbox()
        let file = try sandbox.write(#"{"oauth:tokenCacheV2":"\#(goldenBlob)"}"#, to: "config.json")
        struct Denied: Error {}
        #expect(throws: Denied.self) {
            try DesktopAuth.claudeToken(now: now, configFile: file, secret: { throw Denied() })
        }
    }

    @Test func aMalformedConfigIsAnErrorNotASilentNil() throws {
        let sandbox = Sandbox()
        let file = try sandbox.write("not json", to: "config.json")
        #expect(throws: (any Error).self) {
            try DesktopAuth.claudeToken(now: now, configFile: file, secret: { secret })
        }
    }

    @Test func aCacheThatIsNotAMapOfEntriesYieldsNil() throws {
        let sandbox = Sandbox()
        let blob = Seal.encrypt(Data("[1,2,3]".utf8), secret: secret).base64EncodedString()
        let file = try sandbox.write(#"{"oauth:tokenCacheV2":"\#(blob)"}"#, to: "config.json")
        #expect(try DesktopAuth.claudeToken(now: now, configFile: file, secret: { secret }) == nil)
    }
}
