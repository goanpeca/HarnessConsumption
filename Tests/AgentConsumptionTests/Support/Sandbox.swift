import CommonCrypto
import Foundation

/// A private place to read and write: a temporary directory and an isolated defaults suite, both
/// removed when the test that owns the sandbox ends. Tests use this instead of the real ones.
final class Sandbox {
    let directory: URL
    let defaults: UserDefaults
    private let suite: String

    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("agent-consumption-test-\(UUID())")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suite = "agent-consumption-test-\(UUID())"
        defaults = UserDefaults(suiteName: suite) ?? UserDefaults()
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    func write(_ text: String, to name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }
}

/// Encrypts the way Electron's safeStorage does on macOS (`v10`, AES-128-CBC, PBKDF2 key), so tests can
/// build cache blobs for any secret and payload.
enum Seal {
    static func encrypt(_ plain: Data, secret: String) -> Data {
        var key = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        let salt = Array("saltysalt".utf8)
        CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2), secret, secret.utf8.count, salt, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003, &key, key.count)
        let input = [UInt8](plain)
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var written = 0
        CCCrypt(
            CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
            key, key.count, [UInt8](repeating: 0x20, count: kCCBlockSizeAES128), input, input.count, &output,
            output.count, &written)
        return Data("v10".utf8) + Data(output.prefix(written))
    }

    /// A `config.json` whose `oauth:tokenCacheV2` holds `cache` sealed with `secret`.
    static func config(cache: [String: [String: Any]], secret: String) throws -> String {
        let plain = try JSONSerialization.data(withJSONObject: cache)
        let blob = encrypt(plain, secret: secret).base64EncodedString()
        return #"{"oauth:tokenCacheV2":"\#(blob)"}"#
    }

    static func entry(token: String, expiresAt: Date, plan: String? = "enterprise") -> [String: Any] {
        var entry: [String: Any] = ["token": token, "expiresAt": Int64(expiresAt.timeIntervalSince1970 * 1000)]
        if let plan { entry["subscriptionType"] = plan }
        return entry
    }
}

enum Fixtures {
    /// Noon UTC on the given day: far from midnight, so every time zone sees the same date.
    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }
}
