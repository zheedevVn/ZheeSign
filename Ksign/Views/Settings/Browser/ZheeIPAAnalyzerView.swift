//
//  ZheeIPAAnalyzerView.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ZheeIPAAnalyzerView: View {
    @State private var showPicker = false
    @State private var isAnalyzing = false
    @State private var progressText = ""
    @State private var report: ZheeIPAReport?
    @State private var errorMessage: String?
    @State private var copiedURL: String?
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        List {
            Section {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chọn file IPA")
                                .font(.headline)
                            Text("Phân tích link, secret, provisioning, Mach-O…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(isAnalyzing)

                if isAnalyzing {
                    HStack {
                        ProgressView()
                        Text(progressText.isEmpty ? "Đang phân tích…" : progressText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
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

            if let report {
                if !report.warnings.isEmpty {
                    Section("Cảnh báo") {
                        ForEach(report.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(warning)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                Section("Thông tin app") {
                    infoRow("Tên app", report.appName)
                    infoRow("Bundle ID", report.bundleID)
                    infoRow("Version", "\(report.version) (build \(report.build))")
                    infoRow("iOS tối thiểu", report.minIOS)
                    infoRow("File thực thi", report.executable)
                    infoRow("Kiến trúc", report.architectures.joined(separator: ", "))
                    infoRow("Mã hóa FairPlay", report.isEncrypted ? "Có (đã mã hóa)" : "Không (đã giải mã)")
                    infoRow("Team", report.teamName)
                    infoRow("Provisioning hết hạn", report.provisioningExpiry)
                    if report.provisioningDevices > 0 {
                        infoRow("Thiết bị provisioning", "\(report.provisioningDevices)")
                    }
                    infoRow("Kích thước file", report.fileSize)
                    infoRow("Số chuỗi đã quét", "\(report.scannedStrings)")
                }

                if !report.links.isEmpty {
                    Section("Link (\(report.links.count))") {
                        ForEach(report.linksByCategory, id: \.0) { category, items in
                            DisclosureGroup {
                                ForEach(items) { item in
                                    linkRow(item)
                                }
                            } label: {
                                Label("\(category.rawValue) (\(items.count))", systemImage: category.icon)
                            }
                        }
                    }
                } else {
                    Section("Link") {
                        Text("Không tìm thấy link nào.")
                            .foregroundColor(.secondary)
                    }
                }

                if !report.secrets.isEmpty {
                    Section("Secret / Key (\(report.secrets.count))") {
                        Text("Giá trị đã bị che — chỉ hiện tên key + vài ký tự đầu.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(report.secrets) { secret in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(secret.kind)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(secret.masked)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("Nguồn: \(secret.source)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !report.frameworks.isEmpty || !report.linkedDylibs.isEmpty {
                    Section("Framework & Dylib") {
                        if !report.frameworks.isEmpty {
                            DisclosureGroup("Frameworks trong app (\(report.frameworks.count))") {
                                ForEach(report.frameworks, id: \.self) { fw in
                                    Text(fw)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(report.suspiciousFiles.contains(fw) ? .red : .primary)
                                }
                            }
                        }
                        if !report.linkedDylibs.isEmpty {
                            DisclosureGroup("Dylib liên kết (\(report.linkedDylibs.count))") {
                                ForEach(report.linkedDylibs, id: \.self) { lib in
                                    Text(lib)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        if !report.suspiciousFiles.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundColor(.red)
                                Text("Nghi chèn tweak: \(report.suspiciousFiles.joined(separator: ", "))")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                if !report.permissions.isEmpty {
                    Section("Quyền (\(report.permissions.count))") {
                        ForEach(report.permissions) { perm in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(perm.key)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if !perm.value.isEmpty {
                                    Text(perm.value)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if !report.urlSchemes.isEmpty || !report.queriedSchemes.isEmpty || !report.backgroundModes.isEmpty {
                    Section("Scheme & Background") {
                        if !report.urlSchemes.isEmpty {
                            infoRow("URL Schemes", report.urlSchemes.joined(separator: ", "))
                        }
                        if !report.queriedSchemes.isEmpty {
                            infoRow("App có thể mở", report.queriedSchemes.joined(separator: ", "))
                        }
                        if !report.backgroundModes.isEmpty {
                            infoRow("Chạy nền", report.backgroundModes.joined(separator: ", "))
                        }
                    }
                }

                if !report.entitlements.isEmpty {
                    Section("Entitlements (\(report.entitlements.count))") {
                        ForEach(report.entitlements) { ent in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ent.key)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.semibold)
                                Text(ent.value)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    ShareLink(item: report.summaryText) {
                        Label("Chia sẻ báo cáo (.txt)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = report.summaryText
                        copiedURL = "Đã copy toàn bộ báo cáo"
                    } label: {
                        Label("Copy toàn bộ báo cáo", systemImage: "doc.on.doc")
                    }
                }

                if let copiedURL {
                    Section {
                        Text(copiedURL)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Phân tích IPA")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [UTType.ipa, UTType.tipa],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first, url.startAccessingSecurityScopedResource() {
                    analyze(url: url)
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                errorMessage = "Lỗi chọn file: \(error.localizedDescription)"
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private func linkRow(_ item: ZheeLinkItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text("Nguồn: \(item.source)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = item.url
                copiedURL = "Đã copy: \(item.url.prefix(40))…"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }

    private func analyze(url: URL) {
        isAnalyzing = true
        errorMessage = nil
        report = nil
        copiedURL = nil
        progressText = "Đang chuẩn bị…"
        // Copy vào temp ngay khi còn giữ quyền truy cập file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ZheeAnalyzeInput_\(UUID().uuidString).ipa")
        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            errorMessage = "Không đọc được file: \(error.localizedDescription)"
            isAnalyzing = false
            return
        }
        ZheeIPAAnalyzer().analyze(ipaURL: tempURL, displayName: url.lastPathComponent, onProgress: { step in
            DispatchQueue.main.async { progressText = step }
        }) { result in
            try? FileManager.default.removeItem(at: tempURL)
            switch result {
            case .success(let result):
                report = result
                isAnalyzing = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                isAnalyzing = false
            }
        }
    }
}
