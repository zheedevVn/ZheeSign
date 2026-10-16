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
    @State private var analysisRunID = UUID()
    @State private var progressText = ""
    @State private var progressStep = 0
    @State private var progressLog: [(Date, String)] = []
    @State private var showProgressDetails = true
    @State private var showCompletionAlert = false
    @State private var completionAlertTitle = ""
    @State private var completionAlertMessage = ""
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
                        Text("Chọn file APK")
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

                Text("Bóc tách gói Android ngay trên iPhone — không cần Android / PC")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isAnalyzing {
                    ZheeAnalyzeProgressView(step: progressStep, text: progressText, stages: [
                        "Giải nén APK",
                        "Đọc AndroidManifest.xml",
                        "Phân tích DEX",
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
                if isAnalyzing {
                    ZheeProgressLogView(log: progressLog)
                } else {
                    // Quet xong: gom tien trinh + nhat ky vao 1 muc gap lai.
                    DisclosureGroup("Nhật ký tiến trình (\(progressLog.count))", isExpanded: $showProgressDetails) {
                        ZheeAnalyzeProgressView(step: progressStep, text: progressText, stages: [
                            "Giải nén APK",
                            "Đọc AndroidManifest.xml",
                            "Phân tích DEX",
                            "Quét link & secret",
                        ])
                        ZheeProgressLogView(log: progressLog, showTitle: false)
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
                        Text("Hiển thị đầy đủ giá trị — đừng gửi cho ai.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(report.secrets) { secret in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(secret.kind)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(secret.value)
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
        .toolbar(.hidden, for: .tabBar)
        .alert(completionAlertTitle, isPresented: $showCompletionAlert) {
            Button("Đã rõ", role: .cancel) { showCompletionAlert = false }
        } message: {
            Text(completionAlertMessage)
        }
        .onAppear { restoreSessionIfNeeded() }
        .onReceive(ZheeAPKAnalyzerSession.shared.$revision) { _ in restoreSessionIfNeeded() }
        .sheet(isPresented: $showPicker) {
            ZheeDocumentPicker(contentTypes: [UTType(filenameExtension: "apk") ?? .data]) { url in
                showPicker = false
                if let url {
                    analyze(url: url)
                }
            }
            .ignoresSafeArea()
        }
    }

    /// Restores the last finished analysis from the session (e.g. after
    /// going back and returning). The APK report is self-contained.
    private func restoreSessionIfNeeded() {
        let session = ZheeAPKAnalyzerSession.shared
        // Adopt in-flight (or last) progress first: see IPA view.
        if progressLog.isEmpty {
            isAnalyzing = session.isAnalyzing
            progressText = session.progressText
            progressStep = session.progressStep
            progressLog = session.progressLog
            showProgressDetails = session.isAnalyzing
        }
        guard report == nil else { return }
        guard let saved = session.report else { return }
        report = saved
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
        // Stable copy: see ZheeIPAAnalyzerView — the picker copy (asCopy)
        // may be purged after dismissal, before the late size read.
        let displayName = url.lastPathComponent
        var url = url
        let stableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZheePick_\(UUID().uuidString)_\(displayName)")
        if (try? FileManager.default.copyItem(at: url, to: stableURL)) != nil {
            url = stableURL
        }
        // Drop the previous session; runID drops stale completions.
        let myRun = UUID()
        // Giu app chay nen (audio im lang) cho toi khi quet xong.
        ZheeBackgroundKeeper.shared.start()
        ZheeScanNotifier.requestAuthorization()
        analysisRunID = myRun
        let session = ZheeAPKAnalyzerSession.shared
        session.runID = myRun
        session.report = nil
        session.isAnalyzing = true
        session.progressText = "Đang chuẩn bị…"
        session.progressStep = 0
        session.progressLog = [(Date(), "Bắt đầu phân tích \(displayName)")]
        session.bump()
        isAnalyzing = true
        errorMessage = nil
        report = nil
        copiedNote = nil
        progressText = "Đang chuẩn bị…"
        progressStep = 0
        progressLog = [(Date(), "Bắt đầu phân tích \(displayName)")]
        let startedAt = Date()
        // Picker đã copy file về local (asCopy), dùng trực tiếp được
        ZheeAPKAnalyzer().analyze(apkURL: url, displayName: displayName, onProgress: { step in
            DispatchQueue.main.async {
                progressText = step
                progressStep = Self.stageIndex(for: step)
                progressLog.append((Date(), step))
                let session = ZheeAPKAnalyzerSession.shared
                session.progressText = step
                session.progressStep = Self.stageIndex(for: step)
                session.progressLog = progressLog
                session.bump()
            }
        }) { result in
            // Ket thuc giu nen (ke ca khi completion bi stale-drop).
            defer { DispatchQueue.main.async { ZheeBackgroundKeeper.shared.stop() } }
            try? FileManager.default.removeItem(at: url)
            guard analysisRunID == myRun,
                  ZheeAPKAnalyzerSession.shared.runID == myRun else { return }
            switch result {
            case .success(let result):
                report = result
                progressLog.append((Date(), String(format: "Hoàn tất trong %.1fs", Date().timeIntervalSince(startedAt))))
                progressText = "Đã quét xong"
                showProgressDetails = false
                completionAlertTitle = "Đã quét xong \(result.appLabel)"
                completionAlertMessage = "\(result.links.count) link, \(result.secrets.count) secret, \(result.warnings.count) cảnh báo — hoàn tất trong \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s"
                showCompletionAlert = true
                ZheeScanNotifier.post(title: completionAlertTitle, body: completionAlertMessage)
                isAnalyzing = false
                // Keep the finished analysis in the session so going
                // back does not lose it.
                let session = ZheeAPKAnalyzerSession.shared
                session.report = result
                session.isAnalyzing = false
                session.progressText = progressText
                session.progressStep = progressStep
                session.progressLog = progressLog
                session.bump()
            case .failure(let error):
                errorMessage = error.localizedDescription
                progressLog.append((Date(), "Lỗi: \(error.localizedDescription)"))
                progressText = "Quét thất bại"
                showProgressDetails = false
                completionAlertTitle = "Quét thất bại"
                completionAlertMessage = error.localizedDescription
                showCompletionAlert = true
                ZheeScanNotifier.post(title: completionAlertTitle, body: completionAlertMessage)
                isAnalyzing = false
                let session = ZheeAPKAnalyzerSession.shared
                session.isAnalyzing = false
                session.progressText = progressText
                session.progressStep = progressStep
                session.progressLog = progressLog
                session.bump()
            }
        }
    }
}

extension ZheeAPKAnalyzerView {
    fileprivate static func stageIndex(for text: String) -> Int {
        if text.contains("quét") { return 3 }
        if text.contains("DEX") { return 2 }
        if text.contains("AndroidManifest") { return 1 }
        return 0
    }
}
