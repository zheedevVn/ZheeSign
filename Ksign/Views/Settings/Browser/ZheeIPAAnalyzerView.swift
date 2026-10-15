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
    @State private var patches: [String: String] = [:]
    @State private var editingLink: ZheeLinkItem?
    @State private var editValue = ""
    @State private var isExporting = false
    @State private var exportMessage: String?
    @State private var exportedURL: URL?

    var body: some View {
        List {
            Section {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                        Text("Chọn file IPA")
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

                Text("Phân tích link, secret, provisioning, Mach-O…")
                    .font(.caption)
                    .foregroundColor(.secondary)

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

                if !patches.isEmpty {
                    Section("Giá trị đã sửa (\(patches.count))") {
                        ForEach(Array(patches.keys).sorted(), id: \.self) { oldValue in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(oldValue)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text("→ \(patches[oldValue] ?? "")")
                                        .font(.system(.caption, design: .monospaced))
                                }
                                Spacer()
                                Button {
                                    patches.removeValue(forKey: oldValue)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                Section("Xuất IPA") {
                    Text("IPA xuất ra chưa được ký — mở bằng ZheeSign để ký & cài đặt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        exportPatchedIPA()
                    } label: {
                        Label("Xuất IPA đã chỉnh sửa", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(patches.isEmpty || isExporting || report.workDir == nil)
                    if isExporting {
                        HStack {
                            ProgressView()
                            Text("Đang áp patch & đóng gói…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let exportedURL {
                        ShareLink(item: exportedURL) {
                            Label("Chia sẻ IPA đã sửa", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let exportMessage {
                        Text(exportMessage)
                            .font(.subheadline)
                            .foregroundColor(exportMessage.hasPrefix("Lỗi") ? .red : .green)
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
        .sheet(isPresented: $showPicker) {
            ZheeDocumentPicker(contentTypes: [UTType.ipa, UTType.tipa]) { url in
                showPicker = false
                if let url {
                    analyze(url: url)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $editingLink) { item in
            NavigationView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Giá trị gốc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.url)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Giá trị mới")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Nhập giá trị mới…", text: $editValue)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    Text("Độ dài: \(editValue.utf8.count) / \(item.url.utf8.count) byte")
                        .font(.caption)
                        .foregroundColor(editValue.utf8.count > item.url.utf8.count ? .red : .secondary)
                    if editValue.utf8.count > item.url.utf8.count {
                        Text("Dài hơn gốc — sẽ lấn byte kế tiếp, dễ crash. Dùng giá trị ngắn hơn hoặc link rút gọn.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding()
                .navigationTitle("Sửa giá trị")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { editingLink = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            if !editValue.isEmpty, editValue != item.url {
                                patches[item.url] = editValue
                            }
                            editingLink = nil
                        }
                        .disabled(editValue.isEmpty || editValue.utf8.count > item.url.utf8.count)
                    }
                }
            }
        }
        .onDisappear {
            if let dir = report?.workDir {
                try? FileManager.default.removeItem(at: dir)
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
                editingLink = item
                editValue = item.url
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
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
        if let oldDir = report?.workDir {
            try? FileManager.default.removeItem(at: oldDir)
        }
        isAnalyzing = true
        errorMessage = nil
        report = nil
        copiedURL = nil
        patches = [:]
        exportMessage = nil
        exportedURL = nil
        progressText = "Đang chuẩn bị…"
        // Picker đã copy file về local (asCopy), dùng trực tiếp được
        ZheeIPAAnalyzer().analyze(ipaURL: url, displayName: url.lastPathComponent, onProgress: { step in
            DispatchQueue.main.async { progressText = step }
        }) { result in
            try? FileManager.default.removeItem(at: url)
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

    private func exportPatchedIPA() {
        guard let workDir = report?.workDir, !patches.isEmpty else { return }
        isExporting = true
        exportMessage = nil
        exportedURL = nil
        let baseName = (report?.fileName ?? "app.ipa").replacingOccurrences(of: ".ipa", with: "")
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName)-patched.ipa")
        let currentPatches = patches
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let changed = try ZheeIPAPatcher.applyPatches(workDir: workDir, replacements: currentPatches)
                try ZheeIPAPatcher.repack(workDir: workDir, outputURL: outURL)
                DispatchQueue.main.async {
                    exportedURL = outURL
                    exportMessage = "Đã xuất IPA — sửa \(changed) file. IPA chưa được ký, mở bằng ZheeSign để ký & cài."
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    exportMessage = "Lỗi: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
}
