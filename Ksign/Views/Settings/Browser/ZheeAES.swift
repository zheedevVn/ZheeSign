import Foundation
import Security

/// Pure-Swift AES-256 (FIPS-197), ECB single-block + CBC with PKCS#7.
///
/// CryptoKit has no AES-CBC, and NIP-04 requires AES-256-CBC, so this
/// is a self-contained implementation. The S-box is generated at runtime
/// from GF(2^8) arithmetic instead of a hardcoded 256-entry table.
public enum ZheeAES {

    // MARK: - GF(2^8), polynomial 0x11B

    private static func gfMul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        var a = a, b = b, p: UInt8 = 0
        for _ in 0..<8 {
            if b & 1 != 0 { p ^= a }
            let hi = a & 0x80 != 0
            a <<= 1
            if hi { a ^= 0x1B }
            b >>= 1
        }
        return p
    }

    private static func gfInv(_ a: UInt8) -> UInt8 {
        guard a != 0 else { return 0 }
        for x in 1...255 where gfMul(a, UInt8(x)) == 1 {
            return UInt8(x)
        }
        return 0 // unreachable
    }

    private static func rotl8(_ v: UInt8, _ n: UInt8) -> UInt8 {
        (v << n) | (v >> (8 - n))
    }

    private static let sbox: [UInt8] = {
        (0...255).map { i in
            let inv = gfInv(UInt8(i))
            return inv ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63
        }
    }()

    private static let invSbox: [UInt8] = {
        var inv = [UInt8](repeating: 0, count: 256)
        for (i, v) in sbox.enumerated() { inv[Int(v)] = UInt8(i) }
        return inv
    }()

    // MARK: - Key expansion (AES-256: Nk = 8, Nr = 14)

    private static let rcon: [UInt8] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]

    private static func expandKey(_ key: [UInt8]) -> [[UInt8]] {
        // 60 words of 4 bytes.
        var w = [[UInt8]](repeating: [UInt8](repeating: 0, count: 4), count: 60)
        for i in 0..<8 { w[i] = Array(key[i * 4..<(i + 1) * 4]) }
        for i in 8..<60 {
            var temp = w[i - 1]
            if i % 8 == 0 {
                temp = [sbox[Int(temp[1])] ^ rcon[i / 8 - 1], sbox[Int(temp[2])], sbox[Int(temp[3])], sbox[Int(temp[0])]]
            } else if i % 8 == 4 {
                temp = temp.map { sbox[Int($0)] }
            }
            for j in 0..<4 { w[i][j] = w[i - 8][j] ^ temp[j] }
        }
        return w
    }

    // MARK: - Core

    private static func addRoundKey(_ state: inout [UInt8], _ w: [[UInt8]], _ round: Int) {
        for c in 0..<4 {
            for r in 0..<4 {
                state[r + 4 * c] ^= w[round * 4 + c][r]
            }
        }
    }

    private static func subBytes(_ state: inout [UInt8]) {
        for i in 0..<16 { state[i] = sbox[Int(state[i])] }
    }

    private static func invSubBytes(_ state: inout [UInt8]) {
        for i in 0..<16 { state[i] = invSbox[Int(state[i])] }
    }

    private static func shiftRows(_ state: inout [UInt8]) {
        var next = state
        for r in 0..<4 {
            for c in 0..<4 {
                next[r + 4 * c] = state[r + 4 * ((c + r) % 4)]
            }
        }
        state = next
    }

    private static func invShiftRows(_ state: inout [UInt8]) {
        var next = state
        for r in 0..<4 {
            for c in 0..<4 {
                next[r + 4 * c] = state[r + 4 * ((c + 4 - r) % 4)]
            }
        }
        state = next
    }

    private static func mixColumns(_ state: inout [UInt8]) {
        for c in 0..<4 {
            let i = 4 * c
            let a0 = state[i], a1 = state[i + 1], a2 = state[i + 2], a3 = state[i + 3]
            state[i] = gfMul(a0, 2) ^ gfMul(a1, 3) ^ a2 ^ a3
            state[i + 1] = a0 ^ gfMul(a1, 2) ^ gfMul(a2, 3) ^ a3
            state[i + 2] = a0 ^ a1 ^ gfMul(a2, 2) ^ gfMul(a3, 3)
            state[i + 3] = gfMul(a0, 3) ^ a1 ^ a2 ^ gfMul(a3, 2)
        }
    }

    private static func invMixColumns(_ state: inout [UInt8]) {
        for c in 0..<4 {
            let i = 4 * c
            let a0 = state[i], a1 = state[i + 1], a2 = state[i + 2], a3 = state[i + 3]
            state[i] = gfMul(a0, 14) ^ gfMul(a1, 11) ^ gfMul(a2, 13) ^ gfMul(a3, 9)
            state[i + 1] = gfMul(a0, 9) ^ gfMul(a1, 14) ^ gfMul(a2, 11) ^ gfMul(a3, 13)
            state[i + 2] = gfMul(a0, 13) ^ gfMul(a1, 9) ^ gfMul(a2, 14) ^ gfMul(a3, 11)
            state[i + 3] = gfMul(a0, 11) ^ gfMul(a1, 13) ^ gfMul(a2, 9) ^ gfMul(a3, 14)
        }
    }

    // MARK: - Block API

    public static func encryptBlock(key: Data, plaintext: Data) -> Data? {
        guard key.count == 32, plaintext.count == 16 else { return nil }
        let w = expandKey([UInt8](key))
        var state = [UInt8](plaintext)
        addRoundKey(&state, w, 0)
        for round in 1..<14 {
            subBytes(&state)
            shiftRows(&state)
            mixColumns(&state)
            addRoundKey(&state, w, round)
        }
        subBytes(&state)
        shiftRows(&state)
        addRoundKey(&state, w, 14)
        return Data(state)
    }

    public static func decryptBlock(key: Data, ciphertext: Data) -> Data? {
        guard key.count == 32, ciphertext.count == 16 else { return nil }
        let w = expandKey([UInt8](key))
        var state = [UInt8](ciphertext)
        addRoundKey(&state, w, 14)
        for round in (1..<14).reversed() {
            invShiftRows(&state)
            invSubBytes(&state)
            addRoundKey(&state, w, round)
            invMixColumns(&state)
        }
        invShiftRows(&state)
        invSubBytes(&state)
        addRoundKey(&state, w, 0)
        return Data(state)
    }

    // MARK: - CBC with PKCS#7, IV prepended (16 bytes)

    public static func encryptCBC(key: Data, plaintext: Data) -> Data? {
        guard key.count == 32 else { return nil }
        var iv = Data(count: 16)
        let ok = iv.withUnsafeMutableBytes { SecRandomCopyBytes(nil, 16, $0.baseAddress!) }
        guard ok == errSecSuccess else { return nil }
        var out = iv
        var prev = [UInt8](iv)
        // PKCS#7 pad (always add a block, even when already aligned).
        var padded = [UInt8](plaintext)
        let padLen = 16 - (padded.count % 16)
        padded += [UInt8](repeating: UInt8(padLen), count: padLen)
        for chunk in stride(from: 0, to: padded.count, by: 16) {
            let block = (0..<16).map { padded[chunk + $0] ^ prev[$0] }
            guard let enc = encryptBlock(key: key, plaintext: Data(block)) else { return nil }
            out.append(enc)
            prev = [UInt8](enc)
        }
        return out
    }

    public static func decryptCBC(key: Data, ciphertext: Data) -> Data? {
        guard key.count == 32, ciphertext.count >= 32, ciphertext.count % 16 == 0 else { return nil }
        let bytes = [UInt8](ciphertext)
        var prev = Array(bytes[0..<16])
        var out = [UInt8]()
        for chunk in stride(from: 16, to: bytes.count, by: 16) {
            let block = Array(bytes[chunk..<chunk + 16])
            guard let dec = decryptBlock(key: key, ciphertext: Data(block)) else { return nil }
            out += zip(dec, prev).map { $0 ^ $1 }
            prev = block
        }
        // Validate + strip PKCS#7 padding.
        guard let last = out.last, last >= 1, last <= 16, out.count >= Int(last) else { return nil }
        let padLen = Int(last)
        guard out.suffix(padLen).allSatisfy({ $0 == last }) else { return nil }
        return Data(out.dropLast(padLen))
    }
}
