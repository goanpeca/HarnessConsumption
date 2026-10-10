import CommonCrypto
import Foundation

/// Reads the login Claude Desktop keeps in `config.json` (`oauth:tokenCacheV2`), an Electron
/// safeStorage blob: `v10` + AES-128-CBC, keyed from the "Claude Safe Storage" Keychain item.
/// Read-only: Claude Desktop refreshes the token and owns the rotation.
enum DesktopAuth {
    static let safeStorageService = "Claude Safe Storage"

    struct Token {
        let accessToken: String
        let expiresAt: Date
        let plan: String?
    }

    static var configFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/config.json")
    }

    /// The longest-lived unexpired token in the cache, or nil when Claude Desktop isn't signed in.
    static func claudeToken(now: Date = .now) throws -> Token? {
        guard let config = try? Data(contentsOf: configFile),
            let root = try JSONSerialization.jsonObject(with: config) as? [String: Any],
            let blob = root["oauth:tokenCacheV2"] as? String, let sealed = Data(base64Encoded: blob)
        else { return nil }
        let secret = try Keychain.readPassword(service: safeStorageService)
        let plain = try decrypt(sealed, secret: secret)
        guard let cache = try JSONSerialization.jsonObject(with: plain) as? [String: [String: Any]] else {
            return nil
        }
        return cache.values.compactMap { entry -> Token? in
            guard let token = entry["token"] as? String,
                let expiresMs = (entry["expiresAt"] as? NSNumber)?.doubleValue
            else { return nil }
            return Token(
                accessToken: token, expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
                plan: entry["subscriptionType"] as? String)
        }
        .filter { $0.expiresAt > now }
        .max { $0.expiresAt < $1.expiresAt }
    }

    static func decrypt(_ sealed: Data, secret: String) throws -> Data {
        let prefix = Data("v10".utf8)
        guard sealed.starts(with: prefix) else { throw Keychain.Failure(description: "unknown safeStorage format") }
        var key = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        let salt = Array("saltysalt".utf8)
        let derived = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2), secret, secret.utf8.count, salt, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003, &key, key.count)
        guard derived == kCCSuccess else { throw Keychain.Failure(description: "key derivation failed") }
        let input = [UInt8](sealed.dropFirst(prefix.count))
        let iv = [UInt8](repeating: 0x20, count: kCCBlockSizeAES128)
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var written = 0
        let status = CCCrypt(
            CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
            key, key.count, iv, input, input.count, &output, output.count, &written)
        guard status == kCCSuccess else { throw Keychain.Failure(description: "decrypt failed (\(status))") }
        return Data(output.prefix(written))
    }
}
