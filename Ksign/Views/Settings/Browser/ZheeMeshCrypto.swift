import CryptoKit
import Foundation

/// Per-peer session crypto for the mesh: ECDH (secp256k1) -> HKDF-SHA256
/// -> ChaChaPoly. Runs on top of MultipeerConnectivity, which already
/// authenticates peers, so the plaintext pubkey exchange inherits that.
public enum ZheeMeshCrypto {

    public static func deriveKey(sharedSecret: Data) -> SymmetricKey {
        let input = SymmetricKey(data: sharedSecret)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: input,
            salt: Data("zheechat-mesh-v1".utf8),
            info: Data("mesh-session".utf8),
            outputByteCount: 32
        )
    }

    public static func seal(_ plaintext: Data, key: SymmetricKey) -> Data? {
        guard let box = try? ChaChaPoly.seal(plaintext, using: key) else { return nil }
        return box.combined
    }

    public static func open(_ combined: Data, key: SymmetricKey) -> Data? {
        guard let box = try? ChaChaPoly.SealedBox(combined: combined),
              let plaintext = try? ChaChaPoly.open(box, using: key) else { return nil }
        return plaintext
    }
}
