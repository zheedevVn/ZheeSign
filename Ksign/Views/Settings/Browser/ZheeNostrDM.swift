import CryptoKit
import Foundation

/// NIP-04 encrypted direct messages.
///
/// Shared secret = ECDH(sender secret, receiver pubkey) x-coordinate.
/// Key = SHA256(shared secret). Payload = AES-256-CBC with random IV.
/// Wire format: `base64(ciphertext)?iv=base64(iv)`.
public enum ZheeNostrDM {

    public static func encrypt(senderSecret: Data, receiverPubkeyHex: String, plaintext: String) -> String? {
        guard let receiverPubkey = Data(hex: receiverPubkeyHex),
              let shared = ZheeSecp256k1.sharedSecret(secret: senderSecret, publicKey: receiverPubkey),
              let plaintextData = plaintext.data(using: .utf8) else { return nil }
        let key = Data(SHA256.hash(data: shared))
        // encryptCBC prepends the IV; split it back out for the NIP-04 format.
        guard let blob = ZheeAES.encryptCBC(key: key, plaintext: plaintextData),
              blob.count >= 32 else { return nil }
        let iv = blob.prefix(16)
        let ciphertext = blob.dropFirst(16)
        return ciphertext.base64EncodedString() + "?iv=" + iv.base64EncodedString()
    }

    public static func decrypt(receiverSecret: Data, senderPubkeyHex: String, encrypted: String) -> String? {
        let parts = encrypted.split(separator: "?iv=", maxSplits: 1)
        guard parts.count == 2,
              let ciphertext = Data(base64Encoded: String(parts[0])),
              let iv = Data(base64Encoded: String(parts[1])),
              let senderPubkey = Data(hex: senderPubkeyHex),
              let shared = ZheeSecp256k1.sharedSecret(secret: receiverSecret, publicKey: senderPubkey) else { return nil }
        let key = Data(SHA256.hash(data: shared))
        let blob = iv + ciphertext
        guard let plaintext = ZheeAES.decryptCBC(key: key, ciphertext: blob) else { return nil }
        return String(data: plaintext, encoding: .utf8)
    }
}
