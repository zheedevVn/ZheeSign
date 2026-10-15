//
//  ZheeAPKAnalyzerView.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ZheeAPKAnalyzerView: View {
    @State private var showPicker = false
    @State private var isAnalyzing = false
    @State private var progressText = ""
    @State private var report: ZheeAPKReport?
    @State private var errorMessage: String?
    @State private var copiedNote: String?

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
                            Text("Chọn file APK")
                                .font(.headline)
                            Text("Bóc tách gói Android ngay trên iPhone — không cần Android / PC")
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
                    infoRow("Tên app", report.appLabel)
                    infoRow("Package", report.packageName)
                    infoRow("Version", "\(report.versionName) (\(report.versionCode))")
                    infoRow("minSdk", report.minSdk)
                    infoRow("targetSdk", report.targetSdk)
                    infoRow("Debuggable", report.debuggable)
                    infoRow("allowBackup", report.allowBackup)
                    infoRow("Cleartext traffic", report.usesCleartextTraffic)
                    infoRow("Số file trong APK", "\(report.entryCount)")
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

                if !report.permissions.isEmpty {
                    Section("Quyền (\(report.permissions.count))") {
                        ForEach(report.permissions, id: \.self) { perm in
                            Text(perm)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }

                if !report.components.isEmpty {
                    Section("Component (\(report.components.count))") {
                        ForEach(report.components) { comp in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(comp.name)
                                        .font(.system(.subheadline, design: .monospaced))
                                    Text(comp.type)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("exported: \(comp.exported)")
                                    .font(.caption)
                                    .foregroundColor(comp.exported == "true" ? .orange : .secondary)
                            }
                        }
                    }
                }

                if !report.features.isEmpty {
                    Section("Tính năng yêu cầu") {
                        ForEach(report.features, id: \.self) { feat in
                            Text(feat)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }

                if !report.dexInfos.isEmpty {
                    Section("DEX (\(report.dexInfos.count))") {
                        ForEach(report.dexInfos) { dex in
                            DisclosureGroup("\(dex.file) — v\(dex.version)") {
                                infoRow("Strings", "\(dex.stringCount)")
                                infoRow("Types", "\(dex.typeCount)")
                                infoRow("Methods", "\(dex.methodCount)")
                                infoRow("Classes", "\(dex.classCount)")
                                if !dex.classNames.isEmpty {
                                    DisclosureGroup("Tên class (\(dex.classNames.count) hiện)") {
                                        ForEach(dex.classNames.prefix(200), id: \.self) { cls in
                                            Text(cls)
                                                .font(.system(.caption, design: .monospaced))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if !report.nativeLibs.isEmpty {
                    Section("Thư viện native (.so) (\(report.nativeLibs.count))") {
                        ForEach(report.nativeLibs.prefix(100), id: \.self) { lib in
                            Text(lib)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }

                Section("Chữ ký") {
                    if report.certFiles.isEmpty {
                        Text("Không thấy file chữ ký trong META-INF.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(report.certFiles, id: \.self) { cert in
                            Text(cert)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }

                Section {
                    ShareLink(item: report.summaryText) {
                        Label("Chia sẻ báo cáo (.txt)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = report.summaryText
                        copiedNote = "Đã copy toàn bộ báo cáo"
                    } label: {
                        Label("Copy toàn bộ báo cáo", systemImage: "doc.on.doc")
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
        .navigationTitle("Phân tích APK")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [UTType(filenameExtension: "apk") ?? .data],
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
                copiedNote = "Đã copy: \(item.url.prefix(40))…"
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
        copiedNote = nil
        progressText = "Đang chuẩn bị…"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ZheeAnalyzeInput_\(UUID().uuidString).apk")
        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            errorMessage = "Không đọc được file: \(error.localizedDescription)"
            isAnalyzing = false
            return
        }
        ZheeAPKAnalyzer().analyze(apkURL: tempURL, displayName: url.lastPathComponent, onProgress: { step in
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
