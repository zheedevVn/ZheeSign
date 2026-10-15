import Foundation

// Bech32 (BIP-173) for Nostr NIP-19 display keys: npub / nsec / note.
public enum ZheeBech32 {
    private static let charset: [Character] = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private static let generators: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]

    private static func polymod(_ values: [UInt32]) -> UInt32 {
        var chk: UInt32 = 1
        for v in values {
            let b = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ v
            for i in 0..<5 where (b >> i) & 1 == 1 {
                chk ^= generators[i]
            }
        }
        return chk
    }

    private static func hrpExpand(_ hrp: String) -> [UInt32] {
        var out = hrp.unicodeScalars.map { UInt32($0.value) >> 5 }
        out.append(0)
        out.append(contentsOf: hrp.unicodeScalars.map { UInt32($0.value) & 31 })
        return out
    }

    private static func convertBits(_ data: [UInt8], from: Int, to: Int, pad: Bool) -> [UInt8]? {
        var acc = 0
        var bits = 0
        var out = [UInt8]()
        let maxV = (1 << to) - 1
        for value in data {
            // Compare as Int: (1 << 8) on UInt8 would be 0 (overshift).
        guard Int(value) < (1 << from) else { return nil }
            acc = (acc << from) | Int(value)
            bits += from
            while bits >= to {
                bits -= to
                out.append(UInt8((acc >> bits) & maxV))
            }
        }
        if pad {
            if bits > 0 {
                out.append(UInt8((acc << (to - bits)) & maxV))
            }
        } else if bits >= from || ((acc << (to - bits)) & maxV) != 0 {
            return nil
        }
        return out
    }

    public static func encode(hrp: String, data: Data) -> String? {
        guard let data5 = convertBits([UInt8](data), from: 8, to: 5, pad: true) else { return nil }
        let values = hrpExpand(hrp) + data5.map { UInt32($0) }
        let mod = polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
        var combined = data5
        for i in 0..<6 {
            combined.append(UInt8((mod >> (5 * (5 - i))) & 31))
        }
        return hrp + "1" + combined.map { String(charset[Int($0)]) }.joined()
    }

    /// Returns (hrp, payload bytes) or nil.
    public static func decode(_ string: String) -> (hrp: String, data: Data)? {
        let lower = string.lowercased()
        let upper = string.uppercased()
        guard string == lower || string == upper else { return nil } // no mixed case
        guard let sep = lower.lastIndex(of: "1") else { return nil }
        let hrp = String(lower[lower.startIndex..<sep])
        let dataPart = String(lower[lower.index(after: sep)...])
        guard !hrp.isEmpty, dataPart.count >= 6 else { return nil }
        var values = [UInt32]()
        for ch in dataPart {
            guard let idx = charset.firstIndex(of: ch) else { return nil }
            values.append(UInt32(idx))
        }
        guard polymod(hrpExpand(hrp) + values) == 1 else { return nil }
        let payload5 = values.dropLast(6).map { UInt8($0) }
        guard let payload = convertBits(payload5, from: 5, to: 8, pad: false) else { return nil }
        return (hrp, Data(payload))
    }

    public static func npub(forPublicKey pubkey: Data) -> String? {
        encode(hrp: "npub", data: pubkey)
    }

    public static func nsec(forSecret secret: Data) -> String? {
        encode(hrp: "nsec", data: secret)
    }

    public static func decodeNpub(_ npub: String) -> Data? {
        guard let decoded = decode(npub), decoded.hrp == "npub" else { return nil }
        return decoded.data
    }

    public static func decodeNsec(_ nsec: String) -> Data? {
        guard let decoded = decode(nsec), decoded.hrp == "nsec" else { return nil }
        return decoded.data
    }
}
