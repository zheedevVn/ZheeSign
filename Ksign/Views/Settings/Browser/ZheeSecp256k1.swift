import CryptoKit
import Foundation
import Security

// Pure-Swift secp256k1 + BIP-340 Schnorr signatures. No external dependency.
// Field elements are 4 little-endian UInt64 limbs. The algorithm mirrors a
// Python reference validated against the official BIP-340 test vectors
// (sign 8/8, verify 19/19) and 300 random field operations vs big-int math.
public enum ZheeSecp256k1 {
    public typealias Limbs = [UInt64] // count == 4, little-endian

    public static let p: Limbs = [0xFFFFFFFEFFFFFC2F, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF]
    public static let n: Limbs = [0xBFD25E8CD0364141, 0xBAAEDCE6AF48A03B, 0xFFFFFFFFFFFFFFFE, 0xFFFFFFFFFFFFFFFF]
    private static let pMinus2: Limbs = [0xFFFFFFFEFFFFFC2D, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF]
    private static let pPlus1Over4: Limbs = [0xFFFFFFFFBFFFFF0C, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x3FFFFFFFFFFFFFFF]
    private static let zero: Limbs = [0, 0, 0, 0]
    private static let one: Limbs = [1, 0, 0, 0]

    public struct Point {
        public var x: Limbs
        public var y: Limbs
        public var z: Limbs // Jacobian; nil point is represented by Optional.none
    }

    public static let g = Point(
        x: [0x59F2815B16F81798, 0x029BFCDB2DCE28D9, 0x55A06295CE870B07, 0x79BE667EF9DCBBAC],
        y: [0x9C47D08FFB10D4B8, 0xFD17B448A6855419, 0x5DA4FBFC0E1108A8, 0x483ADA7726A3C465],
        z: one
    )

    // MARK: - Limb helpers

    public static func cmp(_ a: Limbs, _ b: Limbs) -> Int {
        for i in (0..<4).reversed() {
            if a[i] != b[i] { return a[i] > b[i] ? 1 : -1 }
        }
        return 0
    }

    /// arr[idx] += val with carry propagation. arr must have room above idx.
    public static func addInto(_ arr: inout [UInt64], _ idx: Int, _ val: UInt64) {
        var i = idx
        var carry = val
        while carry != 0 && i < arr.count {
            let (sum, overflow) = arr[i].addingReportingOverflow(carry)
            arr[i] = sum
            carry = overflow ? 1 : 0
            i += 1
        }
    }

    private static func add4(_ a: Limbs, _ b: Limbs) -> (Limbs, UInt64) {
        var out = [UInt64](repeating: 0, count: 4)
        var carry: UInt64 = 0
        for i in 0..<4 {
            let (s1, o1) = a[i].addingReportingOverflow(b[i])
            let (s2, o2) = s1.addingReportingOverflow(carry)
            out[i] = s2
            carry = (o1 ? 1 : 0) + (o2 ? 1 : 0)
        }
        return (out, carry)
    }

    private static func sub4(_ a: Limbs, _ b: Limbs) -> (Limbs, UInt64) {
        var out = [UInt64](repeating: 0, count: 4)
        var borrow: UInt64 = 0
        for i in 0..<4 {
            let (d1, o1) = a[i].subtractingReportingOverflow(b[i])
            let (d2, o2) = d1.subtractingReportingOverflow(borrow)
            out[i] = d2
            borrow = (o1 ? 1 : 0) + (o2 ? 1 : 0)
        }
        return (out, borrow)
    }

    public static func isZero(_ a: Limbs) -> Bool { a.allSatisfy { $0 == 0 } }
    public static func isOdd(_ a: Limbs) -> Bool { a[0] & 1 == 1 }

    // MARK: - Field arithmetic mod p

    public static func fpAdd(_ a: Limbs, _ b: Limbs) -> Limbs {
        let (sum, carry) = add4(a, b)
        if carry != 0 || cmp(sum, p) >= 0 {
            return sub4(sum, p).0
        }
        return sum
    }

    public static func fpSub(_ a: Limbs, _ b: Limbs) -> Limbs {
        let (diff, borrow) = sub4(a, b)
        if borrow != 0 {
            return add4(diff, p).0
        }
        return diff
    }

    public static func fpNeg(_ a: Limbs) -> Limbs { fpSub(zero, a) }

    public static func fpMul(_ a: Limbs, _ b: Limbs) -> Limbs {
        // Schoolbook 4x4 -> 8 limbs.
        var t = [UInt64](repeating: 0, count: 8)
        for i in 0..<4 {
            var carry: UInt64 = 0
            for j in 0..<4 {
                let prod = a[i].multipliedFullWidth(by: b[j])
                let (s1, o1) = t[i + j].addingReportingOverflow(prod.low)
                let (s2, o2) = s1.addingReportingOverflow(carry)
                t[i + j] = s2
                // prod.high <= 2^64-2, o1+o2 <= 2, and the extreme case
                // (prod.high == 2^64-2) forces o1+o2 <= 1, so no wrap.
                carry = prod.high &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            }
            addInto(&t, i + 4, carry)
        }
        // Reduce mod p = 2^256 - 2^32 - 977: t = L + H*2^256,
        // 2^256 == 2^32 + 977 (mod p), so t == L + H*(2^32+977).
        let h = Array(t[4..<8])
        // sh = H << 32 (6 limbs)
        var sh = [UInt64](repeating: 0, count: 6)
        for i in 0..<4 {
            addInto(&sh, i, (h[i] & 0xFFFFFFFF) << 32)
            addInto(&sh, i + 1, h[i] >> 32)
        }
        // h977 = H * 977 (6 limbs)
        var h977 = [UInt64](repeating: 0, count: 6)
        var carry977: UInt64 = 0
        for i in 0..<4 {
            // multipliedFullWidth returns (high, low) in that order:
            // use named access, never positional destructuring.
            let prod977 = UInt64(977).multipliedFullWidth(by: h[i])
            let (s1, o1) = prod977.low.addingReportingOverflow(carry977)
            h977[i] = s1
            carry977 = prod977.high &+ (o1 ? 1 : 0)
        }
        h977[4] = carry977
        // s = L + sh + h977 (6 limbs)
        var s = [UInt64](repeating: 0, count: 6)
        for i in 0..<4 { addInto(&s, i, t[i]) }
        for i in 0..<6 { addInto(&s, i, sh[i]) }
        for i in 0..<6 { addInto(&s, i, h977[i]) }
        // Fold overflow limbs (>= 2^256) until gone: extra *= (2^32+977).
        for _ in 0..<10 {
            if s[4] == 0 && s[5] == 0 { break }
            let s4 = s[4], s5 = s[5]
            s[4] = 0; s[5] = 0
            // fold = (s4 + s5*2^64) * (2^32+977), computed limb-wise
            // to avoid any 128-bit intermediate.
            let c: UInt64 = (1 << 32) + 977
            let p4 = s4.multipliedFullWidth(by: c)
            let p5 = s5.multipliedFullWidth(by: c)
            addInto(&s, 0, p4.low)
            addInto(&s, 1, p4.high)
            addInto(&s, 1, p5.low)
            addInto(&s, 2, p5.high)
        }
        var res = Array(s[0..<4])
        while cmp(res, p) >= 0 {
            res = sub4(res, p).0
        }
        return res
    }

    private static func fpPow(_ a: Limbs, _ e: Limbs) -> Limbs {
        var result = one
        for i in (0..<256).reversed() {
            result = fpMul(result, result)
            if (e[i / 64] >> (i % 64)) & 1 == 1 {
                result = fpMul(result, a)
            }
        }
        return result
    }

    public static func fpInv(_ a: Limbs) -> Limbs { fpPow(a, pMinus2) }

    // MARK: - Scalar arithmetic mod n

    public static func snAdd(_ a: Limbs, _ b: Limbs) -> Limbs {
        let (sum, carry) = add4(a, b)
        if carry != 0 || cmp(sum, n) >= 0 {
            return sub4(sum, n).0
        }
        return sum
    }

    public static func snSub(_ a: Limbs, _ b: Limbs) -> Limbs {
        let (diff, borrow) = sub4(a, b)
        if borrow != 0 {
            return add4(diff, n).0
        }
        return diff
    }

    public static func snMul(_ a: Limbs, _ b: Limbs) -> Limbs {
        var t = [UInt64](repeating: 0, count: 8)
        for i in 0..<4 {
            var carry: UInt64 = 0
            for j in 0..<4 {
                let prod = a[i].multipliedFullWidth(by: b[j])
                let (s1, o1) = t[i + j].addingReportingOverflow(prod.low)
                let (s2, o2) = s1.addingReportingOverflow(carry)
                t[i + j] = s2
                carry = prod.high &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            }
            addInto(&t, i + 4, carry)
        }
        // Binary long division: quotient has bits 256..0.
        for bit in (0...256).reversed() {
            let words = bit / 64
            let bits = bit % 64
            var sh = [UInt64](repeating: 0, count: 8)
            for i in 0..<4 {
                if i + words < 8 {
                    sh[i + words] |= n[i] << bits
                }
                if bits != 0 && i + words + 1 < 8 {
                    sh[i + words + 1] |= n[i] >> (64 - bits)
                }
            }
            if cmp8(t, sh) >= 0 {
                t = sub8(t, sh)
            }
        }
        return Array(t[0..<4])
    }

    private static func cmp8(_ a: [UInt64], _ b: [UInt64]) -> Int {
        for i in (0..<8).reversed() {
            if a[i] != b[i] { return a[i] > b[i] ? 1 : -1 }
        }
        return 0
    }

    private static func sub8(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
        var out = [UInt64](repeating: 0, count: 8)
        var borrow: UInt64 = 0
        for i in 0..<8 {
            let (d1, o1) = a[i].subtractingReportingOverflow(b[i])
            let (d2, o2) = d1.subtractingReportingOverflow(borrow)
            out[i] = d2
            borrow = (o1 ? 1 : 0) + (o2 ? 1 : 0)
        }
        return out
    }

    // MARK: - Bytes <-> limbs

    public static func limbsFromBytes32(_ data: Data) -> Limbs? {
        guard data.count == 32 else { return nil }
        var limbs = [UInt64](repeating: 0, count: 4)
        for i in 0..<4 {
            var v: UInt64 = 0
            for j in 0..<8 {
                v = (v << 8) | UInt64(data[24 - 8 * i + j])
            }
            limbs[i] = v
        }
        return limbs
    }

    public static func bytes32FromLimbs(_ limbs: Limbs) -> Data {
        var data = Data(count: 32)
        for i in 0..<4 {
            var v = limbs[i]
            // Big-endian: limb 0 (least significant) occupies bytes 24..<32,
            // limb 3 occupies bytes 0..<8; least significant byte goes last.
            for j in 0..<8 {
                data[24 - 8 * i + 7 - j] = UInt8(v & 0xFF)
                v >>= 8
            }
        }
        return data
    }

    /// Interprets 32 big-endian bytes as a scalar mod n.
    public static func scalarFromBytes(_ data: Data) -> Limbs? {
        guard var limbs = limbsFromBytes32(data) else { return nil }
        while cmp(limbs, n) >= 0 {
            limbs = sub4(limbs, n).0
        }
        return limbs
    }

    // MARK: - Points (Jacobian)

    public static func pointDouble(_ pt: Point?) -> Point? {
        guard let pt else { return nil }
        if isZero(pt.y) { return nil }
        let y2 = fpMul(pt.y, pt.y)
        let s = fpMul(fpMul([4, 0, 0, 0], pt.x), y2)
        let m = fpMul([3, 0, 0, 0], fpMul(pt.x, pt.x))
        let m2 = fpMul(m, m)
        let t = fpSub(m2, fpAdd(s, s))
        let y4 = fpMul(y2, y2)
        let yPrime = fpSub(fpMul(m, fpSub(s, t)), fpMul([8, 0, 0, 0], y4))
        let zPrime = fpMul(fpMul([2, 0, 0, 0], pt.y), pt.z)
        return Point(x: t, y: yPrime, z: zPrime)
    }

    /// Jacobian + affine.
    public static func pointAddMixed(_ jac: Point?, _ aff: Point) -> Point? {
        guard let jac else { return Point(x: aff.x, y: aff.y, z: one) }
        let z1z1 = fpMul(jac.z, jac.z)
        let u2 = fpMul(aff.x, z1z1)
        let s2 = fpMul(fpMul(aff.y, z1z1), jac.z)
        let h = fpSub(u2, jac.x)
        if isZero(h) {
            return cmp(s2, jac.y) == 0 ? pointDouble(jac) : nil
        }
        let r = fpMul([2, 0, 0, 0], fpSub(s2, jac.y))
        let hh = fpMul(h, h)
        let i = fpMul([4, 0, 0, 0], hh)
        let j = fpMul(h, i)
        let v = fpMul(jac.x, i)
        let r2 = fpMul(r, r)
        let x3 = fpSub(fpSub(r2, j), fpAdd(v, v))
        let y3 = fpSub(fpMul(r, fpSub(v, x3)), fpMul([2, 0, 0, 0], fpMul(jac.y, j)))
        // Z3 = 2*Z1*H = (Z1+H)^2 - Z1Z1 - H^2. No extra *Z1 factor:
        // X3/Y3 scale factors require exactly this Z3.
        let z3 = fpSub(fpSub(fpMul(fpAdd(jac.z, h), fpAdd(jac.z, h)), z1z1), hh)
        return Point(x: x3, y: y3, z: z3)
    }

    /// Jacobian + Jacobian.
    public static func pointAdd(_ a: Point?, _ b: Point?) -> Point? {
        guard let a else { return b }
        guard let b else { return a }
        let z1z1 = fpMul(a.z, a.z)
        let z2z2 = fpMul(b.z, b.z)
        let u1 = fpMul(a.x, z2z2)
        let u2 = fpMul(b.x, z1z1)
        let s1 = fpMul(fpMul(a.y, z2z2), b.z)
        let s2 = fpMul(fpMul(b.y, z1z1), a.z)
        let h = fpSub(u2, u1)
        if isZero(h) {
            return cmp(s1, s2) == 0 ? pointDouble(a) : nil
        }
        let r = fpMul([2, 0, 0, 0], fpSub(s2, s1))
        let hh = fpMul(h, h)
        let i = fpMul([4, 0, 0, 0], hh)
        let j = fpMul(h, i)
        let v = fpMul(u1, i)
        let r2 = fpMul(r, r)
        let x3 = fpSub(fpSub(r2, j), fpAdd(v, v))
        let y3 = fpSub(fpMul(r, fpSub(v, x3)), fpMul([2, 0, 0, 0], fpMul(s1, j)))
        let z3 = fpMul(fpSub(fpSub(fpMul(fpAdd(a.z, b.z), fpAdd(a.z, b.z)), z1z1), z2z2), h)
        return Point(x: x3, y: y3, z: z3)
    }

    public static func toAffine(_ pt: Point?) -> Point? {
        guard let pt else { return nil }
        let zi = fpInv(pt.z)
        let zi2 = fpMul(zi, zi)
        let zi3 = fpMul(zi2, zi)
        return Point(x: fpMul(pt.x, zi2), y: fpMul(pt.y, zi3), z: one)
    }

    public static func scalarMult(_ k: Limbs, _ aff: Point) -> Point? {
        var result: Point?
        for i in (0..<256).reversed() {
            result = pointDouble(result)
            if (k[i / 64] >> (i % 64)) & 1 == 1 {
                result = pointAddMixed(result, aff)
            }
        }
        return result
    }

    /// Lifts an x-coordinate to the point with even y, or nil if not on curve.
    public static func liftX(_ x: Limbs) -> Point? {
        guard cmp(x, p) < 0 else { return nil }
        let x3 = fpMul(fpMul(x, x), x)
        let y2 = fpAdd(x3, [7, 0, 0, 0])
        var y = fpPow(y2, pPlus1Over4)
        guard cmp(fpMul(y, y), y2) == 0 else { return nil }
        if isOdd(y) { y = fpSub(zero, y) }
        return Point(x: x, y: y, z: one)
    }

    // MARK: - BIP-340 Schnorr

    private static func taggedHash(tag: String, message: Data) -> Data {
        let tagHash = SHA256.hash(data: Data(tag.utf8))
        var input = Data(tagHash)
        input.append(contentsOf: tagHash)
        input.append(message)
        return Data(SHA256.hash(data: input))
    }

    /// x-only public key (32 bytes) for a 32-byte secret key, or nil if invalid.
    /// ECDH shared secret: x-coordinate of `secret * publicKey` (32 bytes).
    /// Used by NIP-04 (Nostr DMs) and mesh session keys.
    public static func sharedSecret(secret: Data, publicKey: Data) -> Data? {
        guard let scalar = scalarFromBytes(secret),
              let pubLimbs = limbsFromBytes32(publicKey),
              let point = liftX(pubLimbs) else { return nil }
        guard let affine = toAffine(scalarMult(scalar, point)) else { return nil }
        return bytes32FromLimbs(affine.x)
    }

    public static func publicKey(forSecret secret: Data) -> Data? {
        guard let d = scalarFromBytes(secret),
              cmp(d, zero) > 0 else { return nil }
        guard let aff = toAffine(scalarMult(d, g)) else { return nil }
        return bytes32FromLimbs(aff.x)
    }

    public static func sign(secret: Data, message: Data) -> Data? {
        guard var d = scalarFromBytes(secret),
              cmp(d, zero) > 0 else { return nil }
        guard let pubAff = toAffine(scalarMult(d, g)) else { return nil }
        let pub = bytes32FromLimbs(pubAff.x)
        if isOdd(pubAff.y) {
            d = snSub(zero, d)
        }
        var aux = Data(count: 32)
        let randOK = aux.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(nil, 32, ptr.baseAddress!)
        }
        guard randOK == errSecSuccess else { return nil }
        let auxHash = taggedHash(tag: "BIP0340/aux", message: aux)
        guard let auxLimbs = limbsFromBytes32(auxHash) else { return nil }
        var t = [UInt64](repeating: 0, count: 4)
        for i in 0..<4 { t[i] = d[i] ^ auxLimbs[i] }
        guard let tScalar = scalarFromBytes(bytes32FromLimbs(t)) else { return nil }
        var nonceInput = bytes32FromLimbs(tScalar)
        nonceInput.append(pub)
        nonceInput.append(message)
        let kPrimeHash = taggedHash(tag: "BIP0340/nonce", message: nonceInput)
        guard let kPrime = scalarFromBytes(kPrimeHash),
              !isZero(kPrime) else { return nil }
        guard let rAff = toAffine(scalarMult(kPrime, g)) else { return nil }
        var k = kPrime
        if isOdd(rAff.y) {
            k = snSub(zero, kPrime)
        }
        let rBytes = bytes32FromLimbs(rAff.x)
        var challengeInput = rBytes
        challengeInput.append(pub)
        challengeInput.append(message)
        let eHash = taggedHash(tag: "BIP0340/challenge", message: challengeInput)
        guard let e = scalarFromBytes(eHash) else { return nil }
        let s = snAdd(k, snMul(e, d))
        var sig = rBytes
        sig.append(bytes32FromLimbs(s))
        return sig
    }

    public static func verify(publicKey pub: Data, message: Data, signature sig: Data) -> Bool {
        guard pub.count == 32, sig.count == 64,
              let px = limbsFromBytes32(pub),
              // Slices keep the original indices (suffix starts at 32):
              // re-base into fresh Data before indexed byte access.
              let r = limbsFromBytes32(Data(sig.prefix(32))),
              let s = scalarFromBytes(Data(sig.suffix(32))),
              cmp(r, p) < 0,
              let point = liftX(px) else { return false }
        var challengeInput = Data(sig.prefix(32))
        challengeInput.append(pub)
        challengeInput.append(message)
        let eHash = taggedHash(tag: "BIP0340/challenge", message: challengeInput)
        guard let e = scalarFromBytes(eHash) else { return false }
        let sG = scalarMult(s, g)
        let eP = scalarMult(e, point)
        let ePNeg: Point? = eP.map { Point(x: $0.x, y: fpSub(zero, $0.y), z: $0.z) }
        guard let rAff = toAffine(pointAdd(sG, ePNeg)) else { return false }
        if isOdd(rAff.y) { return false }
        return cmp(rAff.x, r) == 0
    }
}
