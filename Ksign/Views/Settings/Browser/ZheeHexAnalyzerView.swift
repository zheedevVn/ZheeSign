//
//  ZheeHexAnalyzerView.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Hex + strings analyzer for ANY file — no need to run the full
//  IPA/APK analysis. Paged hex dump, string extraction, link/secret scan.

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ZheeHexAnalyzerView: View {
    @State private var showPicker = false
    @State private var isAnalyzing = false
    @State private var analysisRunID = UUID()
    @State private var progressText = ""
    @State private var progressStep = 0
    @State private var progressLog: [(Date, String)] = []
    @State private var fileName = ""
    @State private var fileSizeText = ""
    @State private var fileData: Data?
    @State private var pageOffset = 0
    @State private var strings: [String] = []
    @State private var links: [ZheeLinkItem] = []
    @State private var secrets: [ZheeSecretItem] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var copiedNote: String?

    private let pageSize = 512

    private var filteredStrings: [String] {
        if searchText.isEmpty { return strings }
        return strings.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var linksByCategory: [(ZheeLinkCategory, [ZheeLinkItem])] {
        ZheeLinkCategory.allCases.compactMap { cat in
            let items = links.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                        Text("Chọn file bất kỳ")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAnalyzing)

                Text("Xem hex, bóc chuỗi, quét link & secret — không cần chạy phân tích IPA/APK")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isAnalyzing {
                    ZheeAnalyzeProgressView(step: progressStep, text: progressText, stages: [
                        "Đọc file",
                        "Bóc chuỗi",
                        "Quét link & secret",
                    ])
                }

                if let errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }

            if !progressLog.isEmpty {
                ZheeProgressLogView(log: progressLog)
            }

            if fileData != nil {
                Section("File") {
                    HStack {
                        Text("Tên").foregroundColor(.secondary)
                        Spacer()
                        Text(fileName).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Kích thước").foregroundColor(.secondary)
                        Spacer()
                        Text(fileSizeText)
                    }
                    HStack {
                        Text("Số chuỗi tìm thấy").foregroundColor(.secondary)
                        Spacer()
                        Text("\(strings.count)")
                    }
                }
                .font(.subheadline)

                Section("Hex Dump") {
                    if let data = fileData {
                        Text(ZheeBinaryScanner.hexDumpPage(data: data, offset: pageOffset, length: pageSize))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                        HStack {
                            Button {
                                pageOffset = max(0, pageOffset - pageSize)
                            } label: {
                                Label("Trước", systemImage: "chevron.left")
                            }
                            .disabled(pageOffset == 0)
                            Spacer()
                            Text("0x\(String(pageOffset, radix: 16).uppercased()) / 0x\(String(data.count, radix: 16).uppercased())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                if pageOffset + pageSize < data.count {
                                    pageOffset += pageSize
                                }
                            } label: {
                                Label("Sau", systemImage: "chevron.right")
                            }
                            .disabled(pageOffset + pageSize >= data.count)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button {
                            UIPasteboard.general.string = ZheeBinaryScanner.hexDumpPage(data: data, offset: pageOffset, length: pageSize)
                            copiedNote = "Đã copy trang hex hiện tại"
                        } label: {
                            Label("Copy trang hex này", systemImage: "doc.on.doc")
                        }
                    }
                }

                Section("Chuỗi (\(filteredStrings.count))") {
                    TextField("Tìm trong chuỗi…", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    ForEach(filteredStrings.prefix(500), id: \.self) { str in
                        HStack(alignment: .top) {
                            Text(str)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = str
                                copiedNote = "Đã copy chuỗi"
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                            }
                        }
                    }
                    if filteredStrings.count > 500 {
                        Text("…và \(filteredStrings.count - 500) chuỗi nữa. Dùng ô tìm để lọc.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !links.isEmpty {
                    Section("Link (\(links.count))") {
                        ForEach(linksByCategory, id: \.0) { category, items in
                            DisclosureGroup {
                                ForEach(items) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(item.url)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                        Spacer()
                                        Button {
                                            UIPasteboard.general.string = item.url
                                            copiedNote = "Đã copy link"
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                }
                            } label: {
                                Label("\(category.rawValue) (\(items.count))", systemImage: category.icon)
                            }
                        }
                    }
                }

                if !secrets.isEmpty {
                    Section("Secret / Key (\(secrets.count))") {
                        Text("Hiển thị đầy đủ giá trị — đừng gửi cho ai.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(secrets) { secret in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(secret.kind)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(secret.value)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let copiedNote {
                    Section {
                        Text(copiedNote)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Hex & Chuỗi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { restoreSessionIfNeeded() }
        .onReceive(ZheeHexAnalyzerSession.shared.$revision) { _ in restoreSessionIfNeeded() }
        .sheet(isPresented: $showPicker) {
            ZheeDocumentPicker(contentTypes: [.data]) { url in
                showPicker = false
                if let url {
                    loadFile(url: url)
                }
            }
            .ignoresSafeArea()
        }
    }

    /// Restores the last loaded file from the session (e.g. after going
    /// back and returning). The bytes are in memory, so no workDir check.
    private func restoreSessionIfNeeded() {
        guard fileData == nil else { return }
        let session = ZheeHexAnalyzerSession.shared
        guard let saved = session.fileData else { return }
        fileName = session.fileName
        fileSizeText = session.fileSizeText
        fileData = saved
        strings = session.strings
        links = session.links
        secrets = session.secrets
    }

    /// Logs a progress step from any thread (state writes go to main).
    private func logStep(_ step: Int, _ text: String) {
        DispatchQueue.main.async {
            progressText = text
            progressStep = step
            progressLog.append((Date(), text))
        }
    }

    private func loadFile(url: URL) {
        // Stable copy: the picker copy (asCopy) may be purged after
        // dismissal, before the background read runs.
        let displayName = url.lastPathComponent
        var url = url
        let stableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZheePick_\(UUID().uuidString)_\(displayName)")
        if (try? FileManager.default.copyItem(at: url, to: stableURL)) != nil {
            url = stableURL
        }
        // Drop the previous session; runID drops stale completions.
        let myRun = UUID()
        analysisRunID = myRun
        let session = ZheeHexAnalyzerSession.shared
        session.runID = myRun
        session.fileData = nil
        session.strings = []
        session.links = []
        session.secrets = []
        session.bump()
        isAnalyzing = true
        errorMessage = nil
        progressText = "Đang đọc file…"
        progressStep = 0
        progressLog = [(Date(), "Bắt đầu đọc \(displayName)")]
        let startedAt = Date()
        fileName = displayName
        pageOffset = 0
        strings = []
        links = []
        secrets = []
        copiedNote = nil
        searchText = ""
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var size: Int64 = 0
            if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                size = (attrs[.size] as? Int64) ?? 0
            }
            let sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            // Cap at 100MB for memory safety
            let cap: Int64 = 100_000_000
            var data: Data?
            if size <= cap {
                data = try? Data(contentsOf: url)
            } else if let handle = try? FileHandle(forReadingFrom: url) {
                data = try? handle.read(upToCount: Int(cap))
                try? handle.close()
            }
            // Free the stable copy now that the bytes are in memory.
            try? fm.removeItem(at: url)
            guard let data else {
                DispatchQueue.main.async {
                    guard analysisRunID == myRun,
                          ZheeHexAnalyzerSession.shared.runID == myRun else { return }
                    errorMessage = "Không đọc được file."
                    progressLog.append((Date(), "Lỗi: Không đọc được file."))
                    isAnalyzing = false
                }
                return
            }
            logStep(1, "Đang bóc chuỗi…")
            let extracted = ZheeBinaryScanner.extractStrings(from: data)
            logStep(2, "Đang quét link & secret…")
            var linkMap: [String: ZheeLinkItem] = [:]
            var foundSecrets: [ZheeSecretItem] = []
            ZheeBinaryScanner.scanStrings(extracted, source: fileName, linkMap: &linkMap, secrets: &foundSecrets)
            var seen = Set<String>()
            foundSecrets = foundSecrets.filter { item in
                let k = item.kind + "|" + item.value
                guard !seen.contains(k) else { return false }
                seen.insert(k)
                return true
            }
            DispatchQueue.main.async {
                // Stale run (a newer load started): drop the result.
                guard analysisRunID == myRun,
                      ZheeHexAnalyzerSession.shared.runID == myRun else { return }
                progressLog.append((Date(), String(format: "Hoàn tất trong %.1fs — %d chuỗi, %d link, %d secret", Date().timeIntervalSince(startedAt), extracted.count, linkMap.count, foundSecrets.count)))
                fileData = data
                fileSizeText = sizeText + (size > cap ? " (chỉ đọc 100MB đầu)" : "")
                strings = extracted
                links = linkMap.values.sorted { $0.url < $1.url }
                secrets = foundSecrets.sorted { $0.kind < $1.kind }
                isAnalyzing = false
                // Keep the loaded file in the session so going back
                // does not lose it.
                let session = ZheeHexAnalyzerSession.shared
                session.fileName = fileName
                session.fileSizeText = fileSizeText
                session.strings = strings
                session.links = links
                session.secrets = secrets
                session.fileData = data
                session.bump()
            }
        }
    }
}
