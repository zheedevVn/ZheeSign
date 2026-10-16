import CryptoKit
import Foundation
import Security

/// Messenger-style E2EE PIN vault for ZheeChat.
///
/// Model (same as Messenger secure storage):
/// - The user sets a 6-digit PIN. The PIN itself is never stored.
/// - A random salt + the PIN derive a 32-byte key via PBKDF2-HMAC-SHA256.
/// - Message history is AES-256-CBC encrypted with that key.
/// - The derived key is kept in the Keychain, so the same device unlocks
///   automatically. A new device / reinstall / wiped Keychain has no key,
///   so the user must enter the PIN to decrypt history or restore a backup.
/// - Backups embed their own salt, so they can be restored on any device
///   with just the PIN.
public enum ZheePINVault {
    public static let pinLength = 6
    public static let pbkdf2Iterations = 100_000

    private static let saltAccount = "zhee.chat.pin.salt"
    private static let keyAccount = "zhee.chat.pin.key"

    // MARK: - PIN format

public static func isValidPIN(_ pin: String) -> Bool {
        pin.count == pinLength && pin.allSatisfy { $0.isNumber }
    }

    // MARK: - Key derivation (PBKDF2-HMAC-SHA256, 32-byte key = 1 block)

public static func deriveKey(pin: String, salt: Data, iterations: Int = pbkdf2Iterations) -> Data {
        let password = Data(pin.utf8)
        let key = SymmetricKey(data: password)
        // U1 = HMAC(password, salt || INT_32_BE(1))
        var block = salt
        block.append(contentsOf: [0, 0, 0, 1])
        var u = Data(HMAC<SHA256>.authenticationCode(for: block, using: key))
        var result = u
        if iterations > 1 {
            for _ in 1..<iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                for i in result.indices { result[i] ^= u[i] }
            }
        }
        return result
    }

public static func randomSalt() -> Data {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(nil, 16, $0.baseAddress!) }
        return salt
    }

    // MARK: - Encrypt / decrypt local history (salt lives in the Keychain)

public static func encryptHistory(_ plaintext: Data, key: Data) -> Data? {
        ZheeAES.encryptCBC(key: key, plaintext: plaintext)
    }

public static func decryptHistory(_ blob: Data, key: Data) -> Data? {
        ZheeAES.decryptCBC(key: key, ciphertext: blob)
    }

    // MARK: - Backup blob: salt (16 bytes, clear) + AES-CBC(payload)

    /// Caller MUST pass the key derived from the same salt
    /// (`deriveKey(pin:salt:)`), otherwise `decryptBackup` cannot recover it.
public static func encryptBackup(_ plaintext: Data, key: Data, salt: Data) -> Data? {
        guard let enc = ZheeAES.encryptCBC(key: key, plaintext: plaintext) else { return nil }
        return salt + enc
    }

public static func decryptBackup(_ blob: Data, pin: String) -> (plaintext: Data, salt: Data, key: Data)? {
        guard blob.count > 16 else { return nil }
        let salt = blob.prefix(16)
        let key = deriveKey(pin: pin, salt: salt)
        guard let plain = ZheeAES.decryptCBC(key: key, ciphertext: blob.dropFirst(16)) else { return nil }
        return (plain, salt, key)
    }

    // MARK: - Keychain: salt + derived key

public static func loadSalt() -> Data? { loadKeychain(account: saltAccount) }
public static func loadKey() -> Data? { loadKeychain(account: keyAccount) }

public static func saveSalt(_ salt: Data) { saveKeychain(account: saltAccount, data: salt) }
public static func saveKey(_ key: Data) { saveKeychain(account: keyAccount, data: key) }

public static func deleteAll() {
        deleteKeychain(account: saltAccount)
        deleteKeychain(account: keyAccount)
    }

public static var pinEnabled: Bool { loadKey() != nil }

    private static func loadKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func saveKeychain(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
