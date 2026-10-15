import Foundation
import Security

/// Nostr identity for ZheeChat: a secp256k1 keypair stored in the Keychain.
/// Generated once on first use; the user can back it up (nsec) or rotate it.
final class ZheeNostrIdentity: ObservableObject {
    static let shared = ZheeNostrIdentity()

    private static let keychainAccount = "zhee.chat.nostr.secret"
    private static let displayNameKey = "zheechat.displayName"

    @Published private(set) var secret: Data
    @Published var displayName: String {
        didSet {
            UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        }
    }

    private init() {
        if let saved = Self.loadSecret() {
            secret = saved
        } else {
            var bytes = Data(count: 32)
            _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(nil, 32, $0.baseAddress!) }
            secret = bytes
            Self.saveSecret(bytes)
        }
        displayName = UserDefaults.standard.string(forKey: Self.displayNameKey)
            ?? "ZheeUser"
    }

    var publicKey: Data {
        ZheeSecp256k1.publicKey(forSecret: secret) ?? Data(count: 32)
    }

    var publicKeyHex: String {
        publicKey.map { String(format: "%02x", $0) }.joined()
    }

    var npub: String {
        ZheeBech32.npub(forPublicKey: publicKey) ?? publicKeyHex
    }

    var nsec: String {
        ZheeBech32.nsec(forSecret: secret) ?? ""
    }

    /// Short display form: npub1 + first 8 chars.
    var shortNpub: String {
        String(npub.prefix(13)) + "…"
    }

    /// Replace the identity from an nsec string the user pasted. Returns false if invalid.
    @discardableResult
    func importNsec(_ nsec: String) -> Bool {
        guard let data = ZheeBech32.decodeNsec(nsec.trimmingCharacters(in: .whitespacesAndNewlines)),
              data.count == 32,
              ZheeSecp256k1.publicKey(forSecret: data) != nil else { return false }
        secret = data
        Self.saveSecret(data)
        return true
    }

    /// Generate a brand-new identity. The old one is unrecoverable unless backed up.
    func rotate() {
        var bytes = Data(count: 32)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(nil, 32, $0.baseAddress!) }
        secret = bytes
        Self.saveSecret(bytes)
    }

    /// Emergency wipe: deletes the Keychain secret, display name and saved
    /// relays, then generates a fresh identity. The old identity is gone
    /// for good unless its nsec was backed up.
    func wipe() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
        UserDefaults.standard.removeObject(forKey: "zheechat.relays")
        var bytes = Data(count: 32)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(nil, 32, $0.baseAddress!) }
        secret = bytes
        Self.saveSecret(bytes)
        displayName = "ZheeUser"
    }

    // MARK: - Keychain

    private static func loadSecret() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        guard let data = result as? Data, data.count == 32 else { return nil }
        return data
    }

    private static func saveSecret(_ secret: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: secret
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
