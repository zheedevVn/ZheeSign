//
//  ZheeAPKAnalyzer.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Static APK analyzer that runs fully on iOS — no Android, no PC:
//  binary AndroidManifest.xml, DEX headers/strings, native libs, certs,
//  plus the shared link/secret scan.

import Foundation

// MARK: - Models

struct ZheeAPKComponent: Hashable, Identifiable {
    var id: String { type + name }
    let type: String
    let name: String
    let exported: String
}

struct ZheeDexInfo: Hashable, Identifiable {
    var id: String { file }
    let file: String
    let version: String
    let stringCount: Int
    let typeCount: Int
    let methodCount: Int
    let classCount: Int
    let classNames: [String]
}

struct ZheeAPKReport {
    let fileName: String
    let fileSize: String
    let packageName: String
    let appLabel: String
    let versionName: String
    let versionCode: String
    let minSdk: String
    let targetSdk: String
    let permissions: [String]
    let components: [ZheeAPKComponent]
    let features: [String]
    let debuggable: String
    let allowBackup: String
    let usesCleartextTraffic: String
    let dexInfos: [ZheeDexInfo]
    let nativeLibs: [String]
    let certFiles: [String]
    let entryCount: Int
    let links: [ZheeLinkItem]
    let secrets: [ZheeSecretItem]
    let warnings: [String]
    let scannedStrings: Int

    var linksByCategory: [(ZheeLinkCategory, [ZheeLinkItem])] {
        ZheeLinkCategory.allCases.compactMap { cat in
            let items = links.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var summaryText: String {
        var lines: [String] = []
        lines.append("=== ZheeSign — APK Analysis ===")
        lines.append("File: \(fileName) (\(fileSize))")
        lines.append("Package: \(packageName)")
        lines.append("App: \(appLabel)")
        lines.append("Version: \(versionName) (\(versionCode))")
        lines.append("minSdk: \(minSdk)  targetSdk: \(targetSdk)")
        lines.append("Debuggable: \(debuggable)  allowBackup: \(allowBackup)  cleartext: \(usesCleartextTraffic)")
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
        if !permissions.isEmpty {
            lines.append("")
            lines.append("--- Permissions ---")
            lines.append(contentsOf: permissions.map { "- \($0)" })
        }
        if !components.isEmpty {
            lines.append("")
            lines.append("--- Components ---")
            lines.append(contentsOf: components.map { "- [\($0.type)] \($0.name) exported=\($0.exported)" })
        }
        return lines.joined(separator: "\n")
    }
}

enum ZheeAPKAnalyzerError: LocalizedError {
    case notAPK
    case noManifest
    case unzipFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAPK: return "File không phải APK."
        case .noManifest: return "Không tìm thấy AndroidManifest.xml."
        case .unzipFailed(let detail): return "Giải nén APK thất bại. \(detail)"
        }
    }
}

// MARK: - Engine

final class ZheeAPKAnalyzer {

    func analyze(apkURL: URL, displayName: String? = nil, onProgress: @escaping (String) -> Void, completion: @escaping (Result<ZheeAPKReport, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let report = try self.run(apkURL: apkURL, displayName: displayName ?? apkURL.lastPathComponent, onProgress: onProgress)
                DispatchQueue.main.async { completion(.success(report)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

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

    private func run(apkURL: URL, displayName: String, onProgress: @escaping (String) -> Void) throws -> ZheeAPKReport {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("ZheeAnalyzeAPK_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: workDir) }

        // File size: read FIRST (same late-read pitfall as the IPA analyzer).
        let sourceFileSize: Int64? = {
            if let size = (try? apkURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                return Int64(size)
            }
            if let attrs = try? fm.attributesOfItem(atPath: apkURL.path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return nil
        }()

        onProgress("Đang giải nén APK…")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        do {
            try ZheeUnzip.extract(apkURL, to: workDir)
        } catch {
            throw ZheeAPKAnalyzerError.unzipFailed(error.localizedDescription)
        }

        // Entry list
        var entryCount = 0
        if let enumerator = fm.enumerator(at: workDir, includingPropertiesForKeys: nil) {
            for _ in enumerator { entryCount += 1 }
        }

        // MARK: Manifest (binary XML)
        onProgress("Đang đọc AndroidManifest.xml…")
        let manifestURL = workDir.appendingPathComponent("AndroidManifest.xml")
        guard let manifestData = try? Data(contentsOf: manifestURL) else { throw ZheeAPKAnalyzerError.noManifest }
        let manifest = ZheeAXMLParser.parse(data: manifestData)

        // MARK: DEX files
        onProgress("Đang phân tích DEX…")
        var dexInfos: [ZheeDexInfo] = []
        var dexStrings: [String] = []
        if let items = try? fm.contentsOfDirectory(atPath: workDir.path) {
            for item in items.sorted() where item.hasSuffix(".dex") {
                if let data = try? Data(contentsOf: workDir.appendingPathComponent(item)) {
                    let parsed = parseDex(data, file: item)
                    dexInfos.append(parsed.info)
                    dexStrings.append(contentsOf: parsed.allStrings)
                }
            }
        }

        // MARK: Native libs + certs
        var nativeLibs: [String] = []
        let libDir = workDir.appendingPathComponent("lib")
        if let abis = try? fm.contentsOfDirectory(atPath: libDir.path) {
            for abi in abis.sorted() {
                if let files = try? fm.contentsOfDirectory(atPath: libDir.appendingPathComponent(abi).path) {
                    for f in files.sorted() where f.hasSuffix(".so") {
                        nativeLibs.append("lib/\(abi)/\(f)")
                    }
                }
            }
        }
        var certFiles: [String] = []
        let metaDir = workDir.appendingPathComponent("META-INF")
        if let files = try? fm.contentsOfDirectory(atPath: metaDir.path) {
            certFiles = files.filter { $0.hasSuffix(".RSA") || $0.hasSuffix(".DSA") || $0.hasSuffix(".EC") || $0.hasSuffix(".SF") || $0.hasSuffix(".MF") }.sorted()
        }

        // MARK: Links / secrets scan — DEX strings + text files
        onProgress("Đang quét link & secret…")
        var linkMap: [String: ZheeLinkItem] = [:]
        var secrets: [ZheeSecretItem] = []
        ZheeBinaryScanner.scanStrings(dexStrings, source: "classes.dex", linkMap: &linkMap, secrets: &secrets)

        let textExts: Set<String> = ["xml", "json", "js", "html", "htm", "txt", "properties", "md", "arsc"]
        if let enumerator = fm.enumerator(at: workDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent
                if name == "AndroidManifest.xml" { continue }
                guard textExts.contains(fileURL.pathExtension.lowercased()) || fileURL.pathExtension.isEmpty else { continue }
                guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size < 5_000_000 else { continue }
                guard let data = try? Data(contentsOf: fileURL),
                      let text = String(data: data, encoding: .utf8), !text.isEmpty else { continue }
                ZheeBinaryScanner.scanText(text, source: name, linkMap: &linkMap, secrets: &secrets)
            }
        }
        // .so strings (bounded: first 20 libs)
        for lib in nativeLibs.prefix(20) {
            if let data = try? Data(contentsOf: workDir.appendingPathComponent(lib)) {
                let strings = ZheeBinaryScanner.extractStrings(from: data)
                ZheeBinaryScanner.scanStrings(strings, source: (lib as NSString).lastPathComponent, linkMap: &linkMap, secrets: &secrets)
            }
        }
        var seenSecrets = Set<String>()
        secrets = secrets.filter { item in
            let k = item.kind + "|" + item.value
            guard !seenSecrets.contains(k) else { return false }
            seenSecrets.insert(k)
            return true
        }

        // MARK: Warnings
        var warnings: [String] = []
        if manifest.debuggable == "true" {
            warnings.append("App bật debuggable — có thể bị debug / dump lúc chạy.")
        }
        if manifest.allowBackup == "true" {
            warnings.append("allowBackup=true — dữ liệu app có thể bị trích xuất qua adb backup.")
        }
        if manifest.usesCleartextTraffic == "true" {
            warnings.append("usesCleartextTraffic=true — app cho phép traffic http:// không mã hóa.")
        }
        let exportedNoPerm = manifest.components.filter { $0.exported == "true" }
        if !exportedNoPerm.isEmpty {
            warnings.append("Có \(exportedNoPerm.count) component exported — app khác có thể gọi tới.")
        }
        if certFiles.isEmpty {
            warnings.append("Không thấy file chữ ký trong META-INF — APK chưa được ký.")
        }
        if linkMap.keys.contains(where: { $0.hasPrefix("http://") }) {
            warnings.append("Có endpoint dùng http:// không mã hóa.")
        }
        if linkMap.keys.contains(where: { $0.contains("localhost") || $0.contains("127.0.0.1") }) {
            warnings.append("Có endpoint localhost — có thể còn sót code debug.")
        }

        // File size (captured up front; fallback = extracted size)
        let fileSize: String
        if let size = sourceFileSize {
            fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            fileSize = "~" + ByteCountFormatter.string(fromByteCount: Self.totalSize(of: workDir), countStyle: .file)
        }

        return ZheeAPKReport(
            fileName: displayName,
            fileSize: fileSize,
            packageName: manifest.packageName,
            appLabel: manifest.appLabel,
            versionName: manifest.versionName,
            versionCode: manifest.versionCode,
            minSdk: manifest.minSdk,
            targetSdk: manifest.targetSdk,
            permissions: manifest.permissions,
            components: manifest.components,
            features: manifest.features,
            debuggable: manifest.debuggable,
            allowBackup: manifest.allowBackup,
            usesCleartextTraffic: manifest.usesCleartextTraffic,
            dexInfos: dexInfos,
            nativeLibs: nativeLibs,
            certFiles: certFiles,
            entryCount: entryCount,
            links: linkMap.values.sorted { $0.url < $1.url },
            secrets: secrets.sorted { $0.kind < $1.kind },
            warnings: warnings,
            scannedStrings: dexStrings.count
        )
    }

    // MARK: - DEX

    private struct DexParsed {
        let info: ZheeDexInfo
        let allStrings: [String]
    }

    private func parseDex(_ data: Data, file: String) -> DexParsed {
        var version = "—"
        var stringCount = 0, typeCount = 0, methodCount = 0, classCount = 0
        var classNames: [String] = []
        var allStrings: [String] = []
        guard data.count >= 112, data[0] == 0x64, data[1] == 0x65, data[2] == 0x78 else {
            return DexParsed(info: ZheeDexInfo(file: file, version: version, stringCount: 0, typeCount: 0, methodCount: 0, classCount: 0, classNames: []), allStrings: [])
        }
        if let v = String(data: data[4..<7], encoding: .ascii) { version = v }
        let rd32: (Int) -> UInt32 = { off in
            guard data.count >= off + 4 else { return 0 }
            return data.withUnsafeBytes { $0.load(fromByteOffset: off, as: UInt32.self) }.littleEndian
        }
        stringCount = Int(rd32(56)); let stringIdsOff = Int(rd32(60))
        typeCount = Int(rd32(64)); let typeIdsOff = Int(rd32(68))
        methodCount = Int(rd32(88))
        classCount = Int(rd32(96))

        // String table
        var stringTable: [String] = []
        stringTable.reserveCapacity(min(stringCount, 100_000))
        for i in 0..<min(stringCount, 100_000) {
            let entryOff = stringIdsOff + i * 4
            guard data.count >= entryOff + 4 else { break }
            let strOff = Int(rd32(entryOff))
            let (str, _) = readMUTF8(data, strOff)
            stringTable.append(str)
        }
        allStrings = stringTable
        // Type descriptors -> class names
        for i in 0..<min(typeCount, 50_000) {
            let entryOff = typeIdsOff + i * 4
            guard data.count >= entryOff + 4 else { break }
            let strIdx = Int(rd32(entryOff))
            guard strIdx < stringTable.count else { continue }
            let desc = stringTable[strIdx]
            if desc.hasPrefix("L"), desc.hasSuffix(";"), classNames.count < 200 {
                classNames.append(String(desc.dropFirst().dropLast()).replacingOccurrences(of: "/", with: "."))
            }
        }
        return DexParsed(
            info: ZheeDexInfo(file: file, version: version, stringCount: stringCount, typeCount: typeCount, methodCount: methodCount, classCount: classCount, classNames: classNames.sorted()),
            allStrings: allStrings
        )
    }

    private func readMUTF8(_ data: Data, _ offset: Int) -> (String, Int) {
        var pos = offset
        // uleb128 length
        var result: UInt32 = 0
        var shift: UInt32 = 0
        while pos < data.count {
            let b = data[pos]; pos += 1
            result |= UInt32(b & 0x7F) << shift
            if b & 0x80 == 0 { break }
            shift += 7
            if shift > 28 { break }
        }
        let len = Int(result)
        guard pos + len <= data.count else { return ("", pos) }
        let bytes = data[pos..<pos + len]
        // MUTF-8: 0xC0 0x80 means NUL — lossy decode is fine for scanning
        let str = String(decoding: bytes, as: UTF8.self)
        return (str, pos + len)
    }
}

// MARK: - Binary AndroidManifest.xml (AXML)

struct ZheeAndroidManifest {
    var packageName = "—"
    var appLabel = "—"
    var versionName = "—"
    var versionCode = "—"
    var minSdk = "—"
    var targetSdk = "—"
    var permissions: [String] = []
    var components: [ZheeAPKComponent] = []
    var features: [String] = []
    var debuggable = "—"
    var allowBackup = "—"
    var usesCleartextTraffic = "—"
}

enum ZheeAXMLParser {

    static func parse(data: Data) -> ZheeAndroidManifest {
        var manifest = ZheeAndroidManifest()
        guard data.count >= 8 else { return manifest }
        let rd16: (Int) -> UInt16 = { off in
            guard data.count >= off + 2 else { return 0 }
            return data.withUnsafeBytes { $0.load(fromByteOffset: off, as: UInt16.self) }.littleEndian
        }
        let rd32: (Int) -> UInt32 = { off in
            guard data.count >= off + 4 else { return 0 }
            return data.withUnsafeBytes { $0.load(fromByteOffset: off, as: UInt32.self) }.littleEndian
        }

        // String pool — first chunk at offset 8
        var strings: [String] = []
        var pos = 8
        if data.count >= pos + 28, rd16(pos) == 0x0001 {
            let chunkSize = Int(rd32(pos + 4))
            let stringCount = Int(rd32(pos + 8))
            let flags = rd32(pos + 16)
            let stringsStart = Int(rd32(pos + 20))
            let isUTF8 = (flags & 0x100) != 0
            for i in 0..<stringCount {
                let offEntry = pos + 28 + i * 4
                guard data.count >= offEntry + 4 else { break }
                let strOff = pos + stringsStart + Int(rd32(offEntry))
                if isUTF8 {
                    strings.append(readUTF8String(data, strOff))
                } else {
                    strings.append(readUTF16String(data, strOff))
                }
            }
            pos += chunkSize
        }
        let stringAt: (UInt32) -> String = { idx in
            idx < strings.count ? strings[Int(idx)] : ""
        }

        // Walk remaining chunks
        var stack: [(name: String, attrs: [String: String])] = []
        while pos + 8 <= data.count {
            let type = rd16(pos)
            let chunkSize = Int(rd32(pos + 4))
            guard chunkSize >= 8, pos + chunkSize <= data.count else { break }
            if type == 0x0102 { // start element
                let nameIdx = rd32(pos + 20)
                let attrStart = Int(rd16(pos + 24))
                let attrCount = Int(rd16(pos + 28))
                let elementName = stringAt(nameIdx)
                var attrs: [String: String] = [:]
                let attrBase = pos + attrStart
                for i in 0..<attrCount {
                    let aOff = attrBase + i * 20
                    guard aOff + 20 <= pos + chunkSize else { break }
                    let attrName = stringAt(rd32(aOff + 4))
                    let rawValue = rd32(aOff + 8)
                    let dataType = data.count > aOff + 15 ? data[aOff + 15] : 0
                    let dataValue = rd32(aOff + 16)
                    let value: String
                    if rawValue != 0xFFFFFFFF {
                        value = stringAt(rawValue)
                    } else {
                        switch dataType {
                        case 0x03: value = stringAt(dataValue) // string
                        case 0x10: value = "\(dataValue)" // int
                        case 0x12: value = dataValue != 0 ? "true" : "false" // boolean
                        case 0x01: value = String(format: "@0x%08x", dataValue) // reference
                        default: value = String(format: "0x%08x", dataValue)
                        }
                    }
                    if !attrName.isEmpty { attrs[attrName] = value }
                }
                stack.append((elementName, attrs))
                applyElement(&manifest, name: elementName, attrs: attrs, stack: stack)
            } else if type == 0x0103 { // end element
                if !stack.isEmpty { stack.removeLast() }
            }
            pos += chunkSize
        }
        return manifest
    }

    private static func applyElement(_ manifest: inout ZheeAndroidManifest, name: String, attrs: [String: String], stack: [(name: String, attrs: [String: String])]) {
        switch name {
        case "manifest":
            manifest.packageName = attrs["package"] ?? "—"
            manifest.versionName = attrs["versionName"] ?? "—"
            manifest.versionCode = attrs["versionCode"] ?? "—"
        case "uses-sdk":
            manifest.minSdk = attrs["minSdkVersion"] ?? "—"
            manifest.targetSdk = attrs["targetSdkVersion"] ?? "—"
        case "uses-permission", "uses-permission-sdk-23":
            if let perm = attrs["name"], !perm.isEmpty, !manifest.permissions.contains(perm) {
                manifest.permissions.append(perm)
            }
        case "application":
            manifest.debuggable = attrs["debuggable"] ?? "—"
            manifest.allowBackup = attrs["allowBackup"] ?? "—"
            manifest.usesCleartextTraffic = attrs["usesCleartextTraffic"] ?? "—"
            if let label = attrs["label"], !label.isEmpty, label != "@0x00000000" {
                manifest.appLabel = label
            }
        case "activity", "activity-alias", "service", "receiver", "provider":
            let compName = attrs["name"] ?? "—"
            let exported = attrs["exported"] ?? "—"
            manifest.components.append(ZheeAPKComponent(type: name, name: compName, exported: exported))
        case "uses-feature":
            if let feat = attrs["name"], !feat.isEmpty {
                manifest.features.append(feat)
            }
        default:
            break
        }
    }

    private static func readUTF8String(_ data: Data, _ offset: Int) -> String {
        var pos = offset
        // Two varint lengths: utf16 length, then utf8 length
        _ = readUTF8Length(data, &pos)
        let byteLen = readUTF8Length(data, &pos)
        guard byteLen > 0, pos + byteLen <= data.count else { return "" }
        let bytes = data[pos..<pos + byteLen]
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func readUTF8Length(_ data: Data, _ pos: inout Int) -> Int {
        guard pos < data.count else { return 0 }
        let b0 = data[pos]; pos += 1
        if b0 & 0x80 == 0 { return Int(b0) }
        guard pos < data.count else { return 0 }
        let b1 = data[pos]; pos += 1
        return (Int(b0 & 0x7F) << 8) | Int(b1)
    }

    private static func readUTF16String(_ data: Data, _ offset: Int) -> String {
        var pos = offset
        guard pos + 2 <= data.count else { return "" }
        var len = Int(data.withUnsafeBytes { $0.load(fromByteOffset: pos, as: UInt16.self) }.littleEndian)
        pos += 2
        if len & 0x8000 != 0 {
            guard pos + 2 <= data.count else { return "" }
            let len2 = Int(data.withUnsafeBytes { $0.load(fromByteOffset: pos, as: UInt16.self) }.littleEndian)
            pos += 2
            len = ((len & 0x7FFF) << 16) | len2
        }
        guard len > 0, pos + len * 2 <= data.count else { return "" }
        var units: [UInt16] = []
        units.reserveCapacity(len)
        for i in 0..<len {
            units.append(data.withUnsafeBytes { $0.load(fromByteOffset: pos + i * 2, as: UInt16.self) }.littleEndian)
        }
        return String(decoding: units, as: UTF16.self)
    }
}
