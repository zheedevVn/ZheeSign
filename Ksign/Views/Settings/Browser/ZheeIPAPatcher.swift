//
//  ZheeIPAPatcher.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Patch + repack IPA: replace strings in place (new value must be
//  <= old value in UTF-8 bytes, remainder NUL-padded), then re-zip.
//  The patched IPA is unsigned — re-sign on install (ZheeSign does it).

import Foundation
import ZIPFoundation

enum ZheeIPAPatcherError: LocalizedError {
    case noApp
    case noExecutable
    case valueTooLong(String, Int, Int)
    case stringNotFound(String)
    case repackFailed(String)

    var errorDescription: String? {
        switch self {
        case .noApp: return "Không tìm thấy .app trong Payload."
        case .noExecutable: return "Không tìm thấy file thực thi."
        case .valueTooLong(let old, let oldLen, let newLen):
            return "“\(old)” dài \(oldLen) byte — giá trị mới \(newLen) byte, dài hơn gốc. Dùng giá trị ngắn hơn hoặc link rút gọn."
        case .stringNotFound(let s): return "Không tìm thấy chuỗi “\(s)” trong file đã giải nén."
        case .repackFailed(let detail): return "Đóng gói lại thất bại: \(detail)"
        }
    }
}

enum ZheeIPAPatcher {

    /// Apply replacements (old -> new) to the extracted IPA in `workDir`.
    /// Binary: in-place, NUL-padded. Text files (UTF-8): plain replacement.
    /// Returns number of files changed.
    static func applyPatches(workDir: URL, replacements: [String: String]) throws -> Int {
        let fm = FileManager.default
        let payload = workDir.appendingPathComponent("Payload")
        guard let appURL = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension == "app" }) else {
            throw ZheeIPAPatcherError.noApp
        }
        var changedFiles = 0
        var foundAny = Set<String>()

        // Validate all lengths first — fail before touching anything.
        for (old, new) in replacements {
            let oldLen = old.utf8.count
            let newLen = new.utf8.count
            if newLen > oldLen {
                throw ZheeIPAPatcherError.valueTooLong(old, oldLen, newLen)
            }
        }

        // 1. Main executable — binary in-place patch, all occurrences.
        if let exeName = (try? PropertyListSerialization.propertyList(from: Data(contentsOf: appURL.appendingPathComponent("Info.plist")), format: nil)) as? [String: Any],
           let exeFile = exeName["CFBundleExecutable"] as? String {
            let exeURL = appURL.appendingPathComponent(exeFile)
            if var data = try? Data(contentsOf: exeURL) {
                var changed = false
                for (old, new) in replacements {
                    let oldBytes = Array(old.utf8)
                    let newBytes = Array(new.utf8)
                    var searchFrom = 0
                    while let range = findBytes(data, needle: oldBytes, from: searchFrom) {
                        // Replace + NUL-pad to original length
                        data.replaceSubrange(range, with: newBytes + Array(repeating: 0, count: oldBytes.count - newBytes.count))
                        foundAny.insert(old)
                        changed = true
                        searchFrom = range.lowerBound + oldBytes.count
                    }
                }
                if changed {
                    try data.write(to: exeURL)
                    changedFiles += 1
                }
            }
        }

        // 2. Text files in the .app (UTF-8 only) — plain replacement, any length OK.
        let textExts: Set<String> = ["plist", "json", "xml", "js", "html", "htm", "css", "txt", "strings", "md", "conf", "config", "yaml", "yml", "ini"]
        if let enumerator = fm.enumerator(at: appURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                guard textExts.contains(fileURL.pathExtension.lowercased()) else { continue }
                guard let data = try? Data(contentsOf: fileURL),
                      var text = String(data: data, encoding: .utf8) else { continue }
                var changed = false
                for (old, new) in replacements where text.contains(old) {
                    text = text.replacingOccurrences(of: old, with: new)
                    foundAny.insert(old)
                    changed = true
                }
                if changed {
                    try text.write(to: fileURL, atomically: false, encoding: .utf8)
                    changedFiles += 1
                }
            }
        }

        let missing = Set(replacements.keys).subtracting(foundAny)
        if let firstMissing = missing.first {
            throw ZheeIPAPatcherError.stringNotFound(firstMissing)
        }
        return changedFiles
    }

    /// Edit Info.plist: bundle ID / version / build. Empty values are skipped.
    static func applyPlistEdits(workDir: URL, bundleID: String?, version: String?, build: String?) throws {
        let fm = FileManager.default
        let payload = workDir.appendingPathComponent("Payload")
        guard let appURL = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension == "app" }) else {
            throw ZheeIPAPatcherError.noApp
        }
        let infoURL = appURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              var plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            throw ZheeIPAPatcherError.repackFailed("Không đọc được Info.plist.")
        }
        if let bundleID, !bundleID.isEmpty { plist["CFBundleIdentifier"] = bundleID }
        if let version, !version.isEmpty { plist["CFBundleShortVersionString"] = version }
        if let build, !build.isEmpty { plist["CFBundleVersion"] = build }
        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try out.write(to: infoURL)
    }

    /// Replace loose image files. Key = path relative to workDir.
    static func applyImagePatches(workDir: URL, images: [String: Data]) throws {
        for (relPath, data) in images {
            let dest = workDir.appendingPathComponent(relPath)
            try data.write(to: dest)
        }
    }

    /// Make SpringBoard use replaced loose AppIcon files instead of the
    /// compiled Assets.car catalog: strip CFBundleIconName (catalog lookup)
    /// and point CFBundleIconFiles at the replaced loose files.
    /// Returns true when the plist actually changed. No-op when the plist
    /// has no CFBundleIcons or no icon was replaced.
    static func applyIconFallback(workDir: URL, replacedIconBaseNames: [String]) throws -> Bool {
        guard !replacedIconBaseNames.isEmpty else { return false }
        let fm = FileManager.default
        let payload = workDir.appendingPathComponent("Payload")
        guard let appURL = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension == "app" }) else {
            throw ZheeIPAPatcherError.noApp
        }
        let infoURL = appURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              var plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            throw ZheeIPAPatcherError.repackFailed("Không đọc được Info.plist.")
        }
        var changed = false
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            guard var icons = plist[key] as? [String: Any],
                  var primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
                  let iconName = primary["CFBundleIconName"] as? String, !iconName.isEmpty else { continue }
            primary.removeValue(forKey: "CFBundleIconName")
            var files = primary["CFBundleIconFiles"] as? [String] ?? []
            for name in replacedIconBaseNames where !files.contains(name) { files.append(name) }
            primary["CFBundleIconFiles"] = files
            icons["CFBundlePrimaryIcon"] = primary
            plist[key] = icons
            changed = true
        }
        if changed {
            let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            try out.write(to: infoURL)
        }
        return changed
    }

    /// Re-zip the extracted IPA in `workDir` into a new IPA file.
    /// `stripSignature`: drop stale _CodeSignature so the IPA is cleanly
    /// unsigned (sideload .ipa). For .tipa keep it — TrollStore handles it.
    static func repack(workDir: URL, outputURL: URL, stripSignature: Bool = true) throws {
        let fm = FileManager.default
        let payload = workDir.appendingPathComponent("Payload")
        if stripSignature,
           let appURL = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension == "app" }) {
            try? fm.removeItem(at: appURL.appendingPathComponent("_CodeSignature"))
        }
        try? fm.removeItem(at: outputURL)
        guard let archive = Archive(url: outputURL, accessMode: .create) else {
            throw ZheeIPAPatcherError.repackFailed("Không tạo được file IPA.")
        }
        guard let enumerator = fm.enumerator(at: workDir, includingPropertiesForKeys: nil) else {
            throw ZheeIPAPatcherError.repackFailed("Không đọc được thư mục giải nén.")
        }
        do {
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                // Keep full structure: entry name = path relative to workDir (Payload/App.app/...)
                let relPath = fileURL.path.hasPrefix(workDir.path + "/")
                    ? String(fileURL.path.dropFirst(workDir.path.count + 1))
                    : fileURL.lastPathComponent
                try archive.addEntry(with: relPath, relativeTo: workDir, compressionMethod: .deflate)
            }
        } catch {
            throw ZheeIPAPatcherError.repackFailed(error.localizedDescription)
        }
    }

    // MARK: - Byte search

    private static func findBytes(_ data: Data, needle: [UInt8], from start: Int) -> Range<Int>? {
        guard !needle.isEmpty, data.count >= needle.count, start <= data.count - needle.count else { return nil }
        var i = start
        let lastStart = data.count - needle.count
        while i <= lastStart {
            var match = true
            for j in 0..<needle.count where data[i + j] != needle[j] {
                match = false
                break
            }
            if match { return i..<(i + needle.count) }
            i += 1
        }
        return nil
    }
}
