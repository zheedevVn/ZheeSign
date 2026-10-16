//
//  ZheeFilePreviewView.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 16/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Tap a file in the IPA file tree to view it: images render,
//  plists / provisioning show as XML, text shows as-is,
//  anything else falls back to a hex dump of the first 4 KB.
//
//  Two modes for text: Doc (comfortable reading) and Sua (edit the
//  values in place). Saving writes back into the extracted copy, so
//  exporting the IPA applies the edit. Plist edits are validated
//  before saving; mobileprovision edits are spliced back into the
//  original binary wrapper so the file stays intact.

import SwiftUI
import UIKit
import Foundation

struct ZheeFilePreviewView: View {
    let fileURL: URL
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    @State private var content: Content = .loading
    @State private var mode: Mode = .read
    @State private var draft: String = ""
    @State private var originalData: Data?
    @State private var notice: String?
    @State private var noticeIsError = false

    enum Mode { case read, edit }
    enum TextKind { case plain, plist, mobileprovision, hex }

    enum Content {
        case loading
        case text(String, TextKind)
        case image(UIImage)
        case error(String)
    }

    private var isEditable: Bool {
        if case .text(_, let kind) = content { return kind != .hex }
        return false
    }

    private var currentKind: TextKind? {
        if case .text(_, let kind) = content { return kind }
        return nil
    }

    private var currentText: String? {
        if case .text(let text, _) = content { return text }
        return nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let notice {
                    Text(notice)
                        .font(.caption)
                        .foregroundColor(noticeIsError ? .red : .green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background((noticeIsError ? Color.red : Color.green).opacity(0.08))
                }
                Group {
                    switch content {
                    case .loading:
                        ProgressView("Đang mở…")
                    case .text(let text, let kind):
                        if mode == .edit, isEditable {
                            TextEditor(text: $draft)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(4)
                        } else {
                            ScrollView {
                                Text(text)
                                    .font(kind == .hex ? .system(.caption, design: .monospaced) : .body)
                                    .lineSpacing(kind == .hex ? 0 : 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .textSelection(.enabled)
                            }
                        }
                    case .image(let uiImage):
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    case .error(let msg):
                        Text(msg)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                if isEditable {
                    ToolbarItem(placement: .principal) {
                        Picker("Chế độ", selection: $mode) {
                            Text("Đọc").tag(Mode.read)
                            Text("Sửa").tag(Mode.edit)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    if mode == .edit {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") { save() }
                        }
                    }
                }
            }
        }
        .task { load() }
        .onChange(of: mode) { newMode in
            if newMode == .edit, let text = currentText { draft = text }
            notice = nil
        }
    }

    private func load() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.loadContent(fileURL: fileURL)
            let orig: Data? = fileURL.pathExtension.lowercased() == "mobileprovision"
                ? try? Data(contentsOf: fileURL) : nil
            DispatchQueue.main.async {
                content = result
                originalData = orig
            }
        }
    }

    private func save() {
        guard let kind = currentKind else { return }
        switch kind {
        case .plain:
            write(Data(draft.utf8), kind: kind)
        case .plist:
            guard (try? PropertyListSerialization.propertyList(from: Data(draft.utf8), options: [], format: nil)) != nil else {
                showError("Nội dung không phải plist hợp lệ — chưa lưu.")
                return
            }
            write(Data(draft.utf8), kind: kind)
        case .mobileprovision:
            guard (try? PropertyListSerialization.propertyList(from: Data(draft.utf8), options: [], format: nil)) != nil else {
                showError("Nội dung không phải plist hợp lệ — chưa lưu.")
                return
            }
            guard let orig = originalData,
                  let spliced = Self.splicedProvision(editedXML: draft, original: orig) else {
                showError("Không ghi được mobileprovision.")
                return
            }
            write(spliced, kind: kind)
        case .hex:
            return
        }
    }

    private func write(_ data: Data, kind: TextKind) {
        do {
            try data.write(to: fileURL)
            content = .text(draft, kind)
            mode = .read
            notice = "Đã lưu — xuất IPA để áp dụng."
            noticeIsError = false
        } catch {
            showError("Không lưu được: \(error.localizedDescription)")
        }
    }

    private func showError(_ msg: String) {
        notice = msg
        noticeIsError = true
    }

    private static func loadContent(fileURL: URL) -> Content {
        let ext = fileURL.pathExtension.lowercased()
        let total = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0

        // Image
        if ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tiff", "tif"].contains(ext) {
            if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                return .image(uiImage)
            }
            return .error("Không đọc được ảnh.")
        }

        // Plist (binary or XML) -> pretty XML
        if (ext == "plist" || ext == "entitlements") && total <= 5_000_000 {
            if let data = try? Data(contentsOf: fileURL),
               let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let xml = try? PropertyListSerialization.data(fromPropertyList: obj, format: .xml, options: 0),
               let text = String(data: xml, encoding: .utf8) {
                return .text(text, .plist)
            }
        }

        // mobileprovision: binary wrapper around an XML plist
        if ext == "mobileprovision" {
            if let data = try? Data(contentsOf: fileURL), let text = extractPlistXML(from: data) {
                return .text(text, .mobileprovision)
            }
        }

        // Text
        let textExts: Set<String> = ["txt", "json", "xml", "strings", "csv", "md", "markdown",
                                     "js", "ts", "css", "html", "htm", "sh", "py", "rb", "swift",
                                     "m", "h", "c", "cpp", "log", "yaml", "yml", "toml",
                                     "ini", "conf", "cfg", "properties", "gradle", "sql", "graphql"]
        if textExts.contains(ext) {
            let limit = 300_000
            if total <= limit {
                guard let data = try? Data(contentsOf: fileURL) else {
                    return .error("Không đọc được file.")
                }
                return .text(decodeText(data), .plain)
            }
            guard let head = readHead(fileURL: fileURL, limit: limit) else {
                return .error("Không đọc được file.")
            }
            return .text(decodeText(head) + "\n… đã cắt, file gốc \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))", .plain)
        }

        // Binary fallback: hex dump of the first 4 KB
        guard let head = readHead(fileURL: fileURL, limit: 4096) else {
            return .error("Không đọc được file.")
        }
        var hex = ZheeBinaryScanner.hexDumpPage(data: head, offset: 0, length: head.count)
        if total > head.count {
            hex += "\n… còn \(ByteCountFormatter.string(fromByteCount: Int64(total - head.count), countStyle: .file)) chưa hiển thị"
        }
        return .text(hex, .hex)
    }

    private static func decodeText(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    private static func readHead(fileURL: URL, limit: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: limit)
    }

    private static func extractPlistXML(from data: Data) -> String? {
        guard let xmlStart = data.range(of: Data("<?xml".utf8))?.lowerBound,
              let plistEnd = data.range(of: Data("</plist>".utf8))?.upperBound else { return nil }
        return String(data: data[xmlStart..<plistEnd], encoding: .utf8)
    }

    /// Put edited XML back into the original binary wrapper, keeping the
    /// surrounding bytes (header + signature) untouched.
    private static func splicedProvision(editedXML: String, original: Data) -> Data? {
        guard let xmlStart = original.range(of: Data("<?xml".utf8))?.lowerBound,
              let plistEnd = original.range(of: Data("</plist>".utf8))?.upperBound else { return nil }
        var out = Data(original[..<xmlStart])
        out.append(Data(editedXML.utf8))
        out.append(Data(original[plistEnd...]))
        return out
    }
}
