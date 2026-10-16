//
//  ZheeIPAAnalyzer.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Static IPA analyzer: app metadata, provisioning, Mach-O, frameworks,
//  and full link/secret extraction from binary strings + text files.
//  No decompilation, no runtime instrumentation — those need desktop tools.

import Foundation

// MARK: - Models

enum ZheeLinkCategory: String, CaseIterable {
    case telegram = "Telegram"
    case discord = "Discord"
    case api = "API / Endpoint"
    case firebase = "Firebase / Google"
    case webhook = "Webhook"
    case social = "Mạng xã hội"
    case other = "Khác"

    var colorName: String {
        switch self {
        case .telegram: return "blue"
        case .discord: return "indigo"
        case .api: return "orange"
        case .firebase: return "yellow"
        case .webhook: return "purple"
        case .social: return "pink"
        case .other: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .telegram: return "paperplane.fill"
        case .discord: return "message.fill"
        case .api: return "server.rack"
        case .firebase: return "flame.fill"
        case .webhook: return "link.badge.plus"
        case .social: return "person.2.fill"
        case .other: return "link"
        }
    }
}

struct ZheeLinkItem: Hashable, Identifiable {
    var id: String { url }
    let url: String
    let category: ZheeLinkCategory
    let source: String
}

struct ZheeSecretItem: Hashable, Identifiable {
    var id: String { kind + value }
    let kind: String
    let value: String
    let source: String
}

struct ZheeKeyValue: Hashable, Identifiable {
    var id: String { key + value }
    let key: String
    let value: String
}

struct ZheeImageItem: Hashable, Identifiable {
    var id: String { relativePath }
    /// Path relative to the extracted root, e.g. Payload/App.app/icon.png
    let relativePath: String
    let fileName: String
    let size: Int
    let sizeText: String
}

struct ZheeIndicator: Hashable, Identifiable {
    var id: String { title }
    let title: String
    let detail: String
}

struct ZheeFileNode: Hashable, Identifiable {
    var id: String { path }
    let name: String
    /// Path relative to the extracted root, e.g. Payload/App.app/Info.plist
    let path: String
    let isDir: Bool
    let size: Int
    let sizeText: String
    var children: [ZheeFileNode] = []
}

struct ZheeIPAReport {
    /// Extracted IPA folder — kept so patches can be applied + repacked.
    /// Caller owns cleanup.
    let workDir: URL?
    let isTipa: Bool
    let fileName: String
    let fileSize: String
    /// Home-screen icon comes from the Assets.car catalog (CFBundleIconName
    /// set) — SpringBoard ignores the loose AppIcon PNGs.
    let usesCatalogIcon: Bool
    let appName: String
    let bundleID: String
    let version: String
    let build: String
    let minIOS: String
    let executable: String
    let architectures: [String]
    let isEncrypted: Bool
    let linkedDylibs: [String]
    let frameworks: [String]
    let suspiciousFiles: [String]
    let permissions: [ZheeKeyValue]
    let urlSchemes: [String]
    let queriedSchemes: [String]
    let backgroundModes: [String]
    let entitlements: [ZheeKeyValue]
    let teamName: String
    let provisioningExpiry: String
    let provisioningAppID: String
    let provisioningDevices: Int
    let links: [ZheeLinkItem]
    let secrets: [ZheeSecretItem]
    let images: [ZheeImageItem]
    /// Crypto / license-system traces found in binary strings
    let indicators: [ZheeIndicator]
    /// Directory tree of Payload/ (depth <= 3)
    let fileTree: ZheeFileNode
    let warnings: [String]
    let scannedStrings: Int

    var linksByCategory: [(ZheeLinkCategory, [ZheeLinkItem])] {
        ZheeLinkCategory.allCases.compactMap { cat in
            let items = links.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    private func asciiTree(node: ZheeFileNode, prefix: String = "", lines: inout [String]) {
        lines.append(prefix + (node.isDir ? node.name + "/" : node.name + (node.sizeText.isEmpty ? "" : " (\(node.sizeText))")))
        for child in node.children.prefix(30) {
            asciiTree(node: child, prefix: prefix + "  ", lines: &lines)
        }
        if node.children.count > 30 {
            lines.append(prefix + "  … +\(node.children.count - 30) mục")
        }
    }

    private func asciiTree(node: ZheeFileNode) -> [String] {
        var lines: [String] = []
        asciiTree(node: node, lines: &lines)
        return lines
    }

    var summaryText: String {
        var lines: [String] = []
        lines.append("=== ZheeSign — IPA Analysis ===")
        lines.append("File: \(fileName) (\(fileSize))")
        lines.append("App: \(appName)")
        lines.append("Bundle ID: \(bundleID)")
        lines.append("Version: \(version) (build \(build))")
        lines.append("Min iOS: \(minIOS)")
        lines.append("Arch: \(architectures.joined(separator: ", "))")
        lines.append("Encrypted (FairPlay): \(isEncrypted ? "Yes" : "No")")
        lines.append("Team: \(teamName)")
        lines.append("Provisioning expiry: \(provisioningExpiry)")
        if !warnings.isEmpty {
            lines.append("")
            lines.append("--- Warnings ---")
            lines.append(contentsOf: warnings.map { "⚠️ \($0)" })
        }
        if !links.isEmpty {
            lines.append("")
            lines.append("--- Links (\(links.count)) ---")
            lines.append(contentsOf: links.map { "[\($0.category.rawValue)] \($0.url)" })
        }
        if !secrets.isEmpty {
            lines.append("")
            lines.append("--- Secrets (\(secrets.count)) ---")
            lines.append(contentsOf: secrets.map { "[\($0.kind)] \($0.value)" })
        }
        if !frameworks.isEmpty {
            lines.append("")
            lines.append("--- Frameworks ---")
            lines.append(contentsOf: frameworks.map { "- \($0)" })
        }
        if !linkedDylibs.isEmpty {
            lines.append("")
            lines.append("--- Linked dylibs ---")
            lines.append(contentsOf: linkedDylibs.map { "- \($0)" })
        }
        if true {
            lines.append("")
            lines.append("--- File Tree ---")
            lines.append(contentsOf: asciiTree(node: fileTree))
        }
        if !permissions.isEmpty {
            lines.append("")
            lines.append("--- Permissions ---")
            lines.append(contentsOf: permissions.map { "- \($0.key): \($0.value)" })
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Engine

enum ZheeIPAAnalyzerError: LocalizedError {
    case notIPA
    case noPayload
    case noApp
    case noExecutable
    case unzipFailed(String)

    var errorDescription: String? {
        switch self {
        case .notIPA: return "File không phải IPA."
        case .noPayload: return "IPA không có thư mục Payload."
        case .noApp: return "Không tìm thấy .app trong Payload."
        case .noExecutable: return "Không tìm thấy file thực thi."
        case .unzipFailed(let detail): return "Giải nén IPA thất bại. \(detail)"
        }
    }
}

final class ZheeIPAAnalyzer {

    func analyze(ipaURL: URL, displayName: String? = nil, onProgress: @escaping (String) -> Void, completion: @escaping (Result<ZheeIPAReport, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let report = try self.run(ipaURL: ipaURL, displayName: displayName ?? ipaURL.lastPathComponent, onProgress: onProgress)
                DispatchQueue.main.async { completion(.success(report)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func run(ipaURL: URL, displayName: String, onProgress: @escaping (String) -> Void) throws -> ZheeIPAReport {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("ZheeAnalyze_\(UUID().uuidString)", isDirectory: true)

        // File size: read FIRST. A late read saw a deleted file ("—")
        // when the picker's tmp copy was purged mid-scan.
        let sourceFileSize: Int64? = {
            if let size = (try? ipaURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                return Int64(size)
            }
            if let attrs = try? fm.attributesOfItem(atPath: ipaURL.path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return nil
        }()

        onProgress("Đang giải nén IPA…")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        do {
            try ZheeUnzip.extract(ipaURL, to: workDir)
        } catch {
            throw ZheeIPAAnalyzerError.unzipFailed(error.localizedDescription)
        }

        let payload = workDir.appendingPathComponent("Payload")
        guard fm.fileExists(atPath: payload.path) else { throw ZheeIPAAnalyzerError.noPayload }
        let appURLs = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)) ?? []
        guard let appURL = appURLs.first(where: { $0.pathExtension == "app" }) else { throw ZheeIPAAnalyzerError.noApp }

        // MARK: Info.plist
        onProgress("Đang đọc Info.plist…")
        let infoURL = appURL.appendingPathComponent("Info.plist")
        let infoData = try? Data(contentsOf: infoURL)
        let info = (try? PropertyListSerialization.propertyList(from: infoData ?? Data(), format: nil)) as? [String: Any] ?? [:]
        let appName = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
        let bundleID = (info["CFBundleIdentifier"] as? String) ?? "—"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info["CFBundleVersion"] as? String) ?? "—"
        let minIOS = (info["MinimumOSVersion"] as? String) ?? "—"
        let executable = (info["CFBundleExecutable"] as? String) ?? ""

        // Icon source: catalog (Assets.car) vs loose files. When the plist
        // names a catalog icon, SpringBoard ignores the loose AppIcon PNGs.
        var usesCatalogIcon = false
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            if let icons = info[key] as? [String: Any],
               let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconName = primary["CFBundleIconName"] as? String, !iconName.isEmpty {
                usesCatalogIcon = true
            }
        }

        var permissions: [ZheeKeyValue] = []
        for (key, value) in info where key.hasSuffix("UsageDescription") {
            let name = key.replacingOccurrences(of: "UsageDescription", with: "")
            permissions.append(ZheeKeyValue(key: name, value: (value as? String) ?? ""))
        }
        permissions.sort { $0.key < $1.key }

        var urlSchemes: [String] = []
        if let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] {
            for item in urlTypes {
                urlSchemes.append(contentsOf: (item["CFBundleURLSchemes"] as? [String]) ?? [])
            }
        }
        let queriedSchemes = (info["LSApplicationQueriesSchemes"] as? [String]) ?? []
        let backgroundModes = (info["UIBackgroundModes"] as? [String]) ?? []

        // MARK: Frameworks / dylibs in bundle
        var frameworks: [String] = []
        let frameworksDir = appURL.appendingPathComponent("Frameworks")
        if let items = try? fm.contentsOfDirectory(atPath: frameworksDir.path) {
            frameworks = items.sorted()
        }
        var bundleDylibs: [String] = []
        if let items = try? fm.contentsOfDirectory(atPath: appURL.path) {
            bundleDylibs = items.filter { $0.hasSuffix(".dylib") }.sorted()
        }

        let suspiciousKeywords = ["substrate", "substitute", "ellekit", "inject", "tweak", "hook", "frida", "cydia", "cycript", "libhooker", "rocketbootstrap", "preferenceloader", "applist", "cephei"]
        let allBundleLibs = frameworks + bundleDylibs
        let suspiciousFiles = allBundleLibs.filter { name in
            let lower = name.lowercased()
            return suspiciousKeywords.contains { lower.contains($0) }
        }

        // MARK: Provisioning
        onProgress("Đang đọc provisioning…")
        var entitlements: [ZheeKeyValue] = []
        var teamName = "—"
        var provisioningExpiry = "—"
        var provisioningAppID = "—"
        var provisioningDevices = 0
        if let provData = try? Data(contentsOf: appURL.appendingPathComponent("embedded.mobileprovision")),
           let provPlist = extractPlist(from: provData) {
            if let ent = provPlist["Entitlements"] as? [String: Any] {
                entitlements = ent.map { ZheeKeyValue(key: $0.key, value: String(describing: $0.value)) }.sorted { $0.key < $1.key }
            }
            teamName = (provPlist["TeamName"] as? String) ?? "—"
            if let exp = provPlist["ExpirationDate"] as? Date {
                let f = DateFormatter()
                f.dateStyle = .medium
                provisioningExpiry = f.string(from: exp)
                if exp < Date() { /* warning added later */ }
            }
            provisioningAppID = (provPlist["AppIDName"] as? String) ?? "—"
            provisioningDevices = (provPlist["ProvisionedDevices"] as? [Any])?.count ?? 0
        }

        // MARK: Mach-O
        onProgress("Đang phân tích Mach-O…")
        guard !executable.isEmpty else { throw ZheeIPAAnalyzerError.noExecutable }
        let exeURL = appURL.appendingPathComponent(executable)
        guard let exeData = try? Data(contentsOf: exeURL) else { throw ZheeIPAAnalyzerError.noExecutable }
        let macho = parseMachO(exeData)

        // MARK: Strings scan — every Mach-O + text file in the .app
        // Endpoints often hide in dylibs / framework binaries, not the main executable.
        onProgress("Đang quét link & secret…")
        var warnings: [String] = []
        var linkMap: [String: ZheeLinkItem] = [:]
        var secrets: [ZheeSecretItem] = []
        var scannedStrings = 0
        var binaryEntitlements: [ZheeKeyValue] = []
        var indicatorMap: [String: ZheeIndicator] = [:]

        let textExts: Set<String> = ["plist", "json", "xml", "js", "html", "htm", "css", "txt", "strings", "md", "conf", "config", "yaml", "yml", "ini"]
        if let enumerator = fm.enumerator(at: appURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size < 50_000_000 else { continue }
                guard let data = try? Data(contentsOf: fileURL) else { continue }
                if ZheeBinaryScanner.isMachO(data) {
                    let strings = ZheeBinaryScanner.extractStrings(from: data)
                    scannedStrings += strings.count
                    ZheeBinaryScanner.scanStrings(strings, source: fileURL.lastPathComponent, linkMap: &linkMap, secrets: &secrets)
                    for indicator in ZheeBinaryScanner.findBehaviorIndicators(in: strings) {
                        if let existing = indicatorMap[indicator.title] {
                            let merged = Set(existing.detail.components(separatedBy: ", ") + indicator.detail.components(separatedBy: ", ")).sorted().joined(separator: ", ")
                            indicatorMap[indicator.title] = ZheeIndicator(title: indicator.title, detail: merged)
                        } else {
                            indicatorMap[indicator.title] = indicator
                        }
                    }
                    for dict in ZheeBinaryScanner.extractEntitlementDicts(from: data) {
                        for (key, value) in dict {
                            // Binary blobs carry ~70 com.apple.* = true boilerplate keys — keep only notable ones
                            let notable: Set<String> = [
                                "application-identifier", "get-task-allow", "task_for_pid-allow",
                                "run-unsigned-code", "platform-application",
                                "com.apple.security.get-task-allow", "com.apple.system-task-ports",
                                "com.apple.private.security.no-sandbox", "keychain-access-groups",
                                "aps-environment", "com.apple.developer.team-identifier",
                                "com.apple.developer.ubiquity-kvstore-identifier",
                                "com.apple.security.application-groups",
                                "com.apple.developer.associated-domains"
                            ]
                            let keep = notable.contains(key) || key.contains("exception")
                                || value is String || value is [Any]
                            guard keep else { continue }
                            var valueText = String(describing: value)
                            if valueText.count > 300 { valueText = String(valueText.prefix(300)) + "…" }
                            binaryEntitlements.append(ZheeKeyValue(key: key, value: valueText))
                        }
                    }
                } else if textExts.contains(fileURL.pathExtension.lowercased()), size < 5_000_000 {
                    let text = String(data: data, encoding: .utf8) ?? ""
                    if text.isEmpty { continue }
                    ZheeBinaryScanner.scanText(text, source: fileURL.lastPathComponent, linkMap: &linkMap, secrets: &secrets)
                }
            }
        }
        // Merge binary-embedded entitlements (tipa has no mobileprovision)
        for item in binaryEntitlements where !entitlements.contains(where: { $0.key == item.key }) {
            entitlements.append(item)
        }
        entitlements.sort { $0.key < $1.key }

        // Loose images in the .app (not Assets.car — compiled, not editable here)
        var images: [ZheeImageItem] = []
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "tif", "heic"]
        if let enumerator = fm.enumerator(at: appURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                guard imageExts.contains(fileURL.pathExtension.lowercased()) else { continue }
                if fileURL.path.contains("/Frameworks/") { continue }
                let rel = fileURL.path.hasPrefix(workDir.path + "/")
                    ? String(fileURL.path.dropFirst(workDir.path.count + 1))
                    : fileURL.lastPathComponent
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                images.append(ZheeImageItem(
                    relativePath: rel,
                    fileName: fileURL.lastPathComponent,
                    size: size,
                    sizeText: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                ))
                if images.count >= 200 { break }
            }
        }
        images.sort { $0.fileName < $1.fileName }

        // Dedupe secrets
        var seenSecrets = Set<String>()
        secrets = secrets.filter { item in
            let k = item.kind + "|" + item.value
            guard !seenSecrets.contains(k) else { return false }
            seenSecrets.insert(k)
            return true
        }

        // MARK: Warnings
        if !suspiciousFiles.isEmpty {
            warnings.append("Phát hiện file nghi chèn tweak/inject: \(suspiciousFiles.joined(separator: ", "))")
        }
        if let expStr = (try? Data(contentsOf: appURL.appendingPathComponent("embedded.mobileprovision"))).flatMap({ extractPlist(from: $0)?["ExpirationDate"] as? Date }),
           expStr < Date() {
            warnings.append("Provisioning đã hết hạn (\(provisioningExpiry)).")
        }
        if macho.isEncrypted {
            warnings.append("Binary đang bị mã hóa FairPlay — quét string có thể thiếu link.")
        }
        let binaryText = ZheeBinaryScanner.extractStrings(from: exeData).joined(separator: "\n").lowercased()
        if binaryText.contains("frida") || binaryText.contains("gadget") {
            warnings.append("Binary chứa dấu vết Frida gadget.")
        }
        if binaryText.contains("cydia") || binaryText.contains("mobilesubstrate") {
            warnings.append("Binary chứa tham chiếu jailbreak (Cydia/Substrate).")
        }
        if linkMap.keys.contains(where: { $0.hasPrefix("http://") }) {
            warnings.append("Có endpoint dùng http:// không mã hóa.")
        }
        if linkMap.keys.contains(where: { $0.contains("localhost") || $0.contains("127.0.0.1") }) {
            warnings.append("Có endpoint localhost — có thể còn sót code debug.")
        }
        let hasHTTPEndpoint = linkMap.values.contains { item in
            let lower = item.url.lowercased()
            return (lower.hasPrefix("http://") || lower.hasPrefix("https://"))
                && item.category != .telegram && item.category != .discord && item.category != .social
        }
        if !hasHTTPEndpoint {
            if indicatorMap.keys.contains(where: { $0.contains("Mã hóa") }) {
                warnings.append("Endpoint bị mã hóa (AES/DES/...) — phân tích tĩnh không đọc được URL. Muốn thấy endpoint thật phải chạy app + bắt network (mitmproxy/Charles).")
            } else {
                warnings.append("Không tìm thấy endpoint HTTP nào (API/server) — app có thể hoạt động hoàn toàn local/offline.")
            }
        }
        if (try? Data(contentsOf: appURL.appendingPathComponent("embedded.mobileprovision"))) == nil {
            warnings.append("Không có embedded.mobileprovision — app chưa được ký / ký kiểu khác.")
        }

        // MARK: File tree
        let fileTree = buildFileTree(root: payload, base: workDir, depth: 0)

        // MARK: File size (captured up front; fallback = extracted size)
        let fileSize: String
        if let size = sourceFileSize {
            fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            fileSize = "~" + ByteCountFormatter.string(fromByteCount: Self.totalSize(of: payload), countStyle: .file)
        }

        return ZheeIPAReport(
            workDir: workDir,
            isTipa: ipaURL.pathExtension.lowercased() == "tipa",
            fileName: displayName,
            fileSize: fileSize,
            usesCatalogIcon: usesCatalogIcon,
            appName: appName,
            bundleID: bundleID,
            version: version,
            build: build,
            minIOS: minIOS,
            executable: executable,
            architectures: macho.architectures,
            isEncrypted: macho.isEncrypted,
            linkedDylibs: macho.linkedDylibs,
            frameworks: frameworks,
            suspiciousFiles: suspiciousFiles,
            permissions: permissions,
            urlSchemes: urlSchemes.sorted(),
            queriedSchemes: queriedSchemes.sorted(),
            backgroundModes: backgroundModes.sorted(),
            entitlements: entitlements,
            teamName: teamName,
            provisioningExpiry: provisioningExpiry,
            provisioningAppID: provisioningAppID,
            provisioningDevices: provisioningDevices,
            links: linkMap.values.sorted { $0.url < $1.url },
            secrets: secrets.sorted { $0.kind < $1.kind },
            images: images,
            indicators: Array(indicatorMap.values).sorted { $0.title < $1.title },
            fileTree: fileTree,
            warnings: warnings,
            scannedStrings: scannedStrings
        )
    }

    // MARK: - Provisioning plist extraction

    private func extractPlist(from data: Data) -> [String: Any]? {
        guard let startRange = data.range(of: "<plist".data(using: .utf8)!),
              let endRange = data.range(of: "</plist>".data(using: .utf8)!, options: [], in: startRange.upperBound..<data.endIndex) else {
            return nil
        }
        let plistData = data.subdata(in: startRange.lowerBound..<endRange.upperBound)
        return (try? PropertyListSerialization.propertyList(from: plistData, format: nil)) as? [String: Any]
    }

    // MARK: - Mach-O

    private struct MachOInfo {
        var architectures: [String] = []
        var isEncrypted = false
        var linkedDylibs: [String] = []
    }

    private func parseMachO(_ data: Data) -> MachOInfo {
        var info = MachOInfo()
        guard data.count >= 4 else { return info }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }

        if magic == 0xcafebabe || magic == 0xbebafeca {
            // Fat binary (big-endian headers)
            guard data.count >= 8 else { return info }
            let nfat = readBE32(data, 4)
            var offset = 8
            for _ in 0..<nfat {
                guard data.count >= offset + 20 else { break }
                let cputype = readBE32(data, offset)
                let cpusub = readBE32(data, offset + 4)
                let sliceOffset = readBE32(data, offset + 8)
                let sliceSize = readBE32(data, offset + 12)
                _ = cpusub
                info.architectures.append(archName(cputype))
                let slice = data.subdata(in: Int(sliceOffset)..<min(data.count, Int(sliceOffset) + Int(sliceSize)))
                let sub = parseThinMachO(slice)
                info.isEncrypted = info.isEncrypted || sub.isEncrypted
                info.linkedDylibs.append(contentsOf: sub.linkedDylibs)
                offset += 20
            }
        } else {
            let sub = parseThinMachO(data)
            info.architectures = [archName(readLE32(data, 4))]
            info.isEncrypted = sub.isEncrypted
            info.linkedDylibs = sub.linkedDylibs
        }
        info.linkedDylibs = Array(Set(info.linkedDylibs)).sorted()
        info.architectures = Array(Set(info.architectures)).sorted()
        return info
    }

    private func parseThinMachO(_ data: Data) -> MachOInfo {
        var info = MachOInfo()
        guard data.count >= 32 else { return info }
        let magic = readLE32(data, 0)
        let is64 = (magic == 0xfeedfacf)
        guard magic == 0xfeedfacf || magic == 0xfeedface else { return info }
        let ncmds = readLE32(data, 16)
        var offset = is64 ? 32 : 28
        for _ in 0..<ncmds {
            guard data.count >= offset + 8 else { break }
            let cmd = readLE32(data, offset)
            let cmdsize = readLE32(data, offset + 4)
            guard cmdsize >= 8, data.count >= offset + Int(cmdsize) else { break }
            switch cmd {
            case 0x2C, 0x21: // LC_ENCRYPTION_INFO_64 / LC_ENCRYPTION_INFO
                if data.count >= offset + 20 {
                    let cryptid = readLE32(data, offset + 16)
                    if cryptid != 0 { info.isEncrypted = true }
                }
            case 0x0C, 0x18, 0x1F, 0x20, 0x23: // LC_LOAD_DYLIB etc.
                if data.count >= offset + 24 {
                    let nameOffset = Int(readLE32(data, offset + 8))
                    let nameStart = offset + nameOffset
                    if nameStart < data.count {
                        let nameData = data.subdata(in: nameStart..<min(data.count, offset + Int(cmdsize)))
                        if let nul = nameData.firstIndex(of: 0) {
                            let name = String(data: nameData.prefix(upTo: nul), encoding: .utf8) ?? ""
                            if !name.isEmpty { info.linkedDylibs.append(name) }
                        }
                    }
                }
            default:
                break
            }
            offset += Int(cmdsize)
        }
        return info
    }

    private func archName(_ cputype: UInt32) -> String {
        switch cputype {
        case 0x0100000C: return "arm64"
        case 0x0100000D: return "arm64_32"
        case 0x0C: return "arm"
        case 0x07: return "x86"
        case 0x01000007: return "x86_64"
        default: return "cpu_0x\(String(cputype, radix: 16))"
        }
    }

    private func readLE32(_ data: Data, _ offset: Int) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        return data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }.littleEndian
    }

    private func readBE32(_ data: Data, _ offset: Int) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        return data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }.bigEndian
    }

    // MARK: - File tree

    /// Total size of all files under a directory (fallback file size).
    private static func totalSize(of dir: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { continue }
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    private func buildFileTree(root: URL, base: URL, depth: Int) -> ZheeFileNode {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        _ = fm.fileExists(atPath: root.path, isDirectory: &isDir)
        let size = (try? root.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        let rel = root.path.hasPrefix(base.path + "/")
            ? String(root.path.dropFirst(base.path.count + 1))
            : root.lastPathComponent
        var node = ZheeFileNode(
            name: root.lastPathComponent,
            path: rel,
            isDir: isDir.boolValue,
            size: size,
            sizeText: isDir.boolValue ? "" : ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        )
        guard isDir.boolValue, depth < 3 else { return node }
        var children: [ZheeFileNode] = []
        if let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if item.lastPathComponent == ".DS_Store" { continue }
                if item.lastPathComponent == "_CodeSignature" {
                    children.append(ZheeFileNode(name: "_CodeSignature", path: rel + "/_CodeSignature", isDir: true, size: 0, sizeText: "chữ ký"))
                    continue
                }
                children.append(buildFileTree(root: item, base: base, depth: depth + 1))
                if children.count >= 100 { break }
            }
        }
        children.sort { ($0.isDir ? 0 : 1, $0.name) < ($1.isDir ? 0 : 1, $1.name) }
        node.children = children
        return ZheeFileNode(name: node.name, path: node.path, isDir: true, size: size, sizeText: "\(children.count) mục", children: children)
    }
}
