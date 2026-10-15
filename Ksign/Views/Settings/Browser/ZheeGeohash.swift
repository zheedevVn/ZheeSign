import Foundation

/// Geohash (base32) encode/decode for location channels.
/// Precision 5 ≈ 5km cells — coarse enough for a public chat channel.
public enum ZheeGeohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    public static func encode(latitude: Double, longitude: Double, precision: Int = 5) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var even = true
        var bit = 0
        var bits = 0
        var hash = ""
        while hash.count < precision {
            if even {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    bits = bits * 2 + 1
                    lonRange.0 = mid
                } else {
                    bits *= 2
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    bits = bits * 2 + 1
                    latRange.0 = mid
                } else {
                    bits *= 2
                    latRange.1 = mid
                }
            }
            even.toggle()
            bit += 1
            if bit == 5 {
                hash.append(base32[bits])
                bits = 0
                bit = 0
            }
        }
        return hash
    }

    /// Decodes a geohash to (center lat, center lon, lat error, lon error).
    public static func decode(_ hash: String) -> (latitude: Double, longitude: Double, latError: Double, lonError: Double)? {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var even = true
        for char in hash {
            guard let value = base32.firstIndex(of: char) else { return nil }
            for mask in [16, 8, 4, 2, 1] {
                if even {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if value & mask != 0 { lonRange.0 = mid } else { lonRange.1 = mid }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if value & mask != 0 { latRange.0 = mid } else { latRange.1 = mid }
                }
                even.toggle()
            }
        }
        return (
            latitude: (latRange.0 + latRange.1) / 2,
            longitude: (lonRange.0 + lonRange.1) / 2,
            latError: (latRange.1 - latRange.0) / 2,
            lonError: (lonRange.1 - lonRange.0) / 2
        )
    }
}
