//
//  ZheeBinaryScanner.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Shared engine for every analyzer (IPA / APK / any file):
//  string extraction, link categorization, secret patterns, hex dump.

import Foundation

enum ZheeBinaryScanner {

    // MARK: - Strings

    static func extractStrings(from data: Data) -> [String] {
        var results: [String] = []
        results.reserveCapacity(4096)
        // ASCII runs
        var current: [UInt8] = []
        for byte in data {
            if byte >= 0x20 && byte <= 0x7E {
                current.append(byte)
            } else {
                if current.count >= 4 {
                    if let s = String(bytes: current, encoding: .utf8) { results.append(s) }
                }
                current.removeAll(keepingCapacity: true)
            }
        }
        if current.count >= 4, let s = String(bytes: current, encoding: .utf8) { results.append(s) }
        // UTF-16LE runs
        var utf16: [UInt16] = []
        var i = 0
        while i + 1 < data.count {
            let lo = data[i], hi = data[i + 1]
            if hi == 0 && lo >= 0x20 && lo <= 0x7E {
                utf16.append(UInt16(lo))
                i += 2
            } else {
                if utf16.count >= 4 {
                    results.append(String(decoding: utf16, as: UTF16.self))
                }
                utf16.removeAll(keepingCapacity: true)
                i += 1
            }
        }
        if utf16.count >= 4 { results.append(String(decoding: utf16, as: UTF16.self)) }
        return results
    }

    // MARK: - Links

    static func findURLs(in text: String) -> [String] {
        let pattern = #"(?:https?://|tg://|ftp://)[^\s"'<>\\]+|(?:www\.|t\.me/|telegram\.me/|discord\.gg/)[^\s"'<>\\]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var found: [String] = []
        for match in regex.matches(in: text, options: [], range: range) {
            guard let r = Range(match.range, in: text) else { continue }
            var url = String(text[r])
            while let last = url.last, ".,;:!?)]}".contains(last) { url.removeLast() }
            guard url.count >= 8, url.count < 2048 else { continue }
            // Apple DTD links (e.g. PropertyList-1.0.dtd) are plist boilerplate, not endpoints
            if url.contains("/DTDs/") { continue }
            found.append(url)
        }
        return found
    }

    static func categorize(_ url: String) -> ZheeLinkCategory {
        let lower = url.lowercased()
        if lower.contains("t.me") || lower.contains("telegram.me") || lower.contains("api.telegram.org") || lower.hasPrefix("tg://") {
            return .telegram
        }
        if lower.contains("discord.com") || lower.contains("discord.gg") || lower.contains("discordapp.com") {
            return .discord
        }
        if lower.contains("webhook") || lower.contains("hooks.slack.com") {
            return .webhook
        }
        if lower.contains("firebase") || lower.contains("googleapis.com") || lower.contains("firebaseio.com") || lower.contains("firebaseapp.com") {
            return .firebase
        }
        if lower.contains("facebook.com") || lower.contains("twitter.com") || lower.contains("x.com") || lower.contains("instagram.com") || lower.contains("tiktok.com") || lower.contains("youtube.com") {
            return .social
        }
        if lower.contains("/api") || lower.contains("/v1/") || lower.contains("/v2/") || lower.contains("/graphql") || lower.contains("api.") || lower.contains("/rest") {
            return .api
        }
        return .other
    }

    // MARK: - Social handles (telegram:@user -> https://t.me/user)

    static func findSocialHandles(in text: String) -> [String] {
        let pattern = #"telegram:@([A-Za-z0-9_]{3,})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var found: [String] = []
        for match in regex.matches(in: text, options: [], range: range) {
            guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) else { continue }
            found.append("https://t.me/\(text[r])")
        }
        return found
    }

    // MARK: - Mach-O detection

    static func isMachO(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        // MH_MAGIC_64 / MH_MAGIC / FAT_MAGIC / FAT_CIGAM (LE + BE)
        return magic == 0xfeedfacf || magic == 0xfeedface || magic == 0xcafebabe || magic == 0xbebafeca
    }

    // MARK: - Entitlements embedded in a binary (plist blob)

    static func extractEntitlementDicts(from data: Data) -> [[String: Any]] {
        var results: [[String: Any]] = []
        var searchFrom = data.startIndex
        let plistStart = "<plist".data(using: .utf8)!
        let plistEnd = "</plist>".data(using: .utf8)!
        let entitlementKeys = ["application-identifier", "get-task-allow", "task_for_pid-allow", "run-unsigned-code", "platform-application", "com.apple.security.get-task-allow"]
        while let startRange = data.range(of: plistStart, options: [], in: searchFrom..<data.endIndex),
              let endRange = data.range(of: plistEnd, options: [], in: startRange.upperBound..<data.endIndex) {
            let blob = data.subdata(in: startRange.lowerBound..<endRange.upperBound)
            if let dict = (try? PropertyListSerialization.propertyList(from: blob, format: nil)) as? [String: Any] {
                let hits = dict.keys.filter { key in
                    entitlementKeys.contains(key) || key.hasPrefix("com.apple")
                }
                if hits.count >= 2 {
                    results.append(dict)
                }
            }
            searchFrom = endRange.upperBound
            if results.count >= 3 { break }
        }
        return results
    }

    // MARK: - Behavior indicators (crypto / license system)

    /// Detects crypto + license-system traces in binary strings.
    /// When an app encrypts its endpoint (AES/DES...), static analysis
    /// cannot recover the URL — but these traces prove it exists.
    static func findBehaviorIndicators(in strings: [String]) -> [ZheeIndicator] {
        let blob = strings.joined(separator: "\n")
        var out: [ZheeIndicator] = []
        let groups: [(title: String, keywords: [String])] = [
            ("Mã hóa (endpoint có thể bị mã hóa)", [
                "AES256", "AES128", "DESEncrypted", "DESEncrypt", "CASTEncrypted",
                "decryptFromBase64", "encryptToBase64", "sealRequest", "openResponse:respKey"
            ]),
            ("Hệ thống License / Key", [
                "apiclient_", "APIClientOverlay", "showLoginForm", "keyTextField",
                "VKKeychainUDID", "showLoginError", "onLoginSubmit"
            ]),
        ]
        for group in groups {
            let hits = group.keywords.filter { blob.contains($0) }
            if !hits.isEmpty {
                out.append(ZheeIndicator(title: group.title, detail: hits.joined(separator: ", ")))
            }
        }
        return out
    }

    // MARK: - Secrets (values are masked, never stored)

    static func findSecrets(in text: String, source: String) -> [ZheeSecretItem] {
        let patterns: [(kind: String, regex: String)] = [
            ("Telegram bot token", #"bot\d{6,12}:[A-Za-z0-9_-]{20,}"#),
            ("API key", #"(?i)(api[_-]?key|apikey)\s*[:=]\s*["']?[^"'\s,}]{8,}"#),
            ("Secret", #"(?i)(client[_-]?secret|app[_-]?secret|secret[_-]?key)\s*[:=]\s*["']?[^"'\s,}]{8,}"#),
            ("Access token", #"(?i)(access[_-]?token|auth[_-]?token)\s*[:=]\s*["']?[^"'\s,}]{8,}"#),
            ("Bearer token", #"(?i)bearer\s+[A-Za-z0-9._\-]{16,}"#),
            ("Password", #"(?i)(password|passwd|pwd)\s*[:=]\s*["']?[^"'\s,}]{4,}"#),
            ("Private key", #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#),
            ("AWS key", #"(?i)(aws[_-]?secret|aws[_-]?access[_-]?key)\s*[:=]\s*["']?[^"'\s,}]{8,}"#),
            ("Webhook URL", #"(?i)https?://[^\s"'<>]*?(webhook|hooks\.slack\.com)[^\s"'<>]*"#),
        ]
        var results: [ZheeSecretItem] = []
        for (kind, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, options: [], range: range).prefix(20) {
                guard let r = Range(match.range, in: text) else { continue }
                let raw = String(text[r])
                results.append(ZheeSecretItem(kind: kind, masked: maskSecret(raw), source: source))
            }
        }
        return results
    }

    static func maskSecret(_ raw: String) -> String {
        let trimmed = raw.count > 120 ? String(raw.prefix(120)) + "…" : raw
        if let sep = trimmed.firstIndex(where: { $0 == "=" || $0 == ":" }) {
            let key = trimmed[..<sep]
            let value = trimmed[trimmed.index(after: sep)...]
            let head = value.prefix(4)
            return "\(key)=\(head)••••••"
        }
        if trimmed.count > 12 {
            return "\(trimmed.prefix(6))••••••\(trimmed.suffix(4))"
        }
        return "••••••"
    }

    // MARK: - Scan a text blob (chunked) into links + secrets

    static func scanStrings(_ strings: [String], source: String, linkMap: inout [String: ZheeLinkItem], secrets: inout [ZheeSecretItem]) {
        var chunk = ""
        chunk.reserveCapacity(1_000_000)
        for s in strings {
            chunk += s
            chunk += "\n"
            if chunk.count > 1_000_000 {
                scanText(chunk, source: source, linkMap: &linkMap, secrets: &secrets)
                chunk.removeAll(keepingCapacity: true)
            }
        }
        if !chunk.isEmpty { scanText(chunk, source: source, linkMap: &linkMap, secrets: &secrets) }
    }

    static func scanText(_ text: String, source: String, linkMap: inout [String: ZheeLinkItem], secrets: inout [ZheeSecretItem]) {
        for url in findURLs(in: text) {
            if linkMap[url] == nil {
                linkMap[url] = ZheeLinkItem(url: url, category: categorize(url), source: source)
            }
        }
        for handle in findSocialHandles(in: text) {
            if linkMap[handle] == nil {
                linkMap[handle] = ZheeLinkItem(url: handle, category: .telegram, source: source)
            }
        }
        secrets.append(contentsOf: findSecrets(in: text, source: source))
    }

    // MARK: - Hex dump (one page)

    static func hexDumpPage(data: Data, offset: Int, length: Int) -> String {
        guard offset < data.count else { return "" }
        let end = min(data.count, offset + length)
        var lines: [String] = []
        var i = offset
        while i < end {
            let rowEnd = min(end, i + 16)
            let row = data[i..<rowEnd]
            var hexParts: [String] = []
            var ascii = ""
            for byte in row {
                hexParts.append(String(format: "%02x", byte))
                ascii.append((byte >= 0x20 && byte <= 0x7E) ? Character(UnicodeScalar(byte)) : ".")
            }
            while hexParts.count < 16 { hexParts.append("  ") }
            // Group hex in 2 halves for readability
            let hexStr = hexParts[0..<8].joined(separator: " ") + "  " + hexParts[8..<16].joined(separator: " ")
            lines.append(String(format: "%08x  %@  %@", i, hexStr, ascii))
            i = rowEnd
        }
        return lines.joined(separator: "\n")
    }
}
