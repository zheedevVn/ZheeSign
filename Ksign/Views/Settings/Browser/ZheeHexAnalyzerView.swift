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
                        Text("Giá trị đã bị che — chỉ hiện tên key + vài ký tự đầu.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(secrets) { secret in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(secret.kind)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(secret.masked)
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

    private func loadFile(url: URL) {
        isAnalyzing = true
        errorMessage = nil
        fileName = url.lastPathComponent
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
            guard let data else {
                DispatchQueue.main.async {
                    errorMessage = "Không đọc được file."
                    isAnalyzing = false
                }
                return
            }
            let extracted = ZheeBinaryScanner.extractStrings(from: data)
            var linkMap: [String: ZheeLinkItem] = [:]
            var foundSecrets: [ZheeSecretItem] = []
            ZheeBinaryScanner.scanStrings(extracted, source: fileName, linkMap: &linkMap, secrets: &foundSecrets)
            var seen = Set<String>()
            foundSecrets = foundSecrets.filter { item in
                let k = item.kind + "|" + item.masked
                guard !seen.contains(k) else { return false }
                seen.insert(k)
                return true
            }
            DispatchQueue.main.async {
                fileData = data
                fileSizeText = sizeText + (size > cap ? " (chỉ đọc 100MB đầu)" : "")
                strings = extracted
                links = linkMap.values.sorted { $0.url < $1.url }
                secrets = foundSecrets.sorted { $0.kind < $1.kind }
                isAnalyzing = false
            }
        }
    }
}
