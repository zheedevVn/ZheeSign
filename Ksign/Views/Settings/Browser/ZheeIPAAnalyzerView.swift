//
//  ZheeIPAAnalyzerView.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ZheeIPAAnalyzerView: View {
    @State private var showPicker = false
    @State private var previewNode: ZheeFileNode?
    @State private var isAnalyzing = false
    @State private var analysisRunID = UUID()
    @State private var progressText = ""
    @State private var progressStep = 0
    @State private var progressLog: [(Date, String)] = []
    @State private var showProgressDetails = true
    @State private var showCompletionAlert = false
    @State private var completionAlertTitle = ""
    @State private var completionAlertMessage = ""
    @State private var report: ZheeIPAReport?
    @State private var errorMessage: String?
    @State private var copiedURL: String?
    @State private var expandedCategories: Set<String> = []
    @State private var patches: [String: String] = [:]
    @State private var editBundleID = ""
    @State private var editVersion = ""
    @State private var editBuild = ""
    @State private var origBundleID = ""
    @State private var origVersion = ""
    @State private var origBuild = ""
    @State private var imagePatches: [String: Data] = [:]
    @State private var replacingImage: ZheeImageItem?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
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
                    ZheeAnalyzeProgressView(step: progressStep, text: progressText, stages: [
                        "Giải nén IPA",
                        "Đọc Info.plist",
                        "Đọc provisioning",
                        "Phân tích Mach-O",
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
                            "Giải nén IPA",
                            "Đọc Info.plist",
                            "Đọc provisioning",
                            "Phân tích Mach-O",
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
                            .listRowBackground(Color.orange.opacity(0.07))
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.22))
                                Image(systemName: report.isTipa ? "t.square.fill" : "app.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.appName)
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(report.bundleID)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        HStack(spacing: 16) {
                            heroStat("Version", "v\(report.version)")
                            heroStat("Build", report.build)
                            heroStat("Dung lượng", report.fileSize)
                            heroStat("Chuỗi quét", "\(report.scannedStrings)")
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }

                Section("Thông tin app") {
                    infoRow("iOS tối thiểu", report.minIOS)
                    infoRow("File thực thi", report.executable)
                    infoRow("Kiến trúc", report.architectures.joined(separator: ", "))
                    infoRow("Mã hóa FairPlay", report.isEncrypted ? "Có (đã mã hóa)" : "Không (đã giải mã)")
                    infoRow("Team", report.teamName)
                    infoRow("Provisioning hết hạn", report.provisioningExpiry)
                    if report.provisioningDevices > 0 {
                        infoRow("Thiết bị provisioning", "\(report.provisioningDevices)")
                    }
                }

                if !report.links.isEmpty {
                    Section("Link (\(report.links.count))") {
                        ForEach(report.linksByCategory, id: \.0) { category, items in
                            DisclosureGroup {
                                ForEach(items) { item in
                                    linkRow(item)
                                }
                            } label: {
                                Label {
                                    Text("\(category.rawValue) (\(items.count))")
                                } icon: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(categoryColor(category).opacity(0.15))
                                        Image(systemName: category.icon)
                                            .font(.caption)
                                            .foregroundColor(categoryColor(category))
                                    }
                                    .frame(width: 28, height: 28)
                                }
                            }
                        }
                    }
                } else {
                    Section("Link") {
                        Text("Không tìm thấy link nào.")
                            .foregroundColor(.secondary)
                    }
                }

                if !report.indicators.isEmpty {
                    Section("Dấu vết") {
                        ForEach(report.indicators) { indicator in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(indicator.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(indicator.detail)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
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

                Section("Sơ đồ cấu trúc") {
                    Text("Luồng hoạt động")
                        .font(.subheadline)
                        .bold()
                    flowNode(icon: "app.fill", title: report.appName, subtitle: "\(report.bundleID) • v\(report.version) (\(report.build))", color: .blue)
                    flowArrow()
                    flowNode(icon: "cpu", title: "Executable: \(report.executable)", subtitle: "\(report.architectures.joined(separator: ", ")) • \(report.isEncrypted ? "Mã hóa FairPlay" : "Không mã hóa")", color: .orange)
                    flowArrow()
                    HStack(spacing: 8) {
                        flowNode(icon: "folder.fill", title: "Frameworks", subtitle: "\(report.frameworks.count) framework", color: .purple)
                        flowNode(icon: "link", title: "Dylib", subtitle: "\(report.linkedDylibs.count) thư viện", color: .purple)
                    }
                    flowArrow()
                    flowNode(icon: "key.fill", title: "Entitlements", subtitle: "\(report.entitlements.count) quyền • Team: \(report.teamName)", color: .green)
                    flowArrow()
                    flowNode(icon: "lock.shield", title: "Quyền riêng tư", subtitle: "\(report.permissions.count) quyền • \(report.backgroundModes.count) background mode", color: .red)
                    flowArrow()
                    flowNode(icon: "network", title: "Kết nối ra ngoài", subtitle: "\(report.links.count) link • \(report.urlSchemes.count) URL scheme", color: .teal)
                    Text("Cây thư mục")
                        .font(.subheadline)
                        .bold()
                        .padding(.top, 8)
                    fileTreeView(node: report.fileTree)
                }

                Section("Sửa thông tin app") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle ID").font(.caption).foregroundColor(.secondary)
                        TextField("vn.example.app", text: $editBundleID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version").font(.caption).foregroundColor(.secondary)
                        TextField("1.0", text: $editVersion)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build").font(.caption).foregroundColor(.secondary)
                        TextField("1", text: $editBuild)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    Text("Đổi Bundle ID = cài thành app khác, không ghi đè app gốc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !report.images.isEmpty {
                    Section("Ảnh (\(report.images.count))") {
                        Text("Chỉ ảnh rời trong .app — ảnh trong Assets.car chưa sửa được.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if report.usesCatalogIcon {
                            Text("Icon màn hình chính nằm trong Assets.car — khi xuất, app tự chuyển sang dùng ảnh rời đã Thay để đổi icon.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ForEach(report.images) { image in
                            HStack(spacing: 10) {
                                if let workDir = report.workDir,
                                   image.size < 2_000_000,
                                   let uiImage = UIImage(contentsOfFile: workDir.appendingPathComponent(image.relativePath).path) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipped()
                                        .cornerRadius(8)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, height: 40)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(image.fileName)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .lineLimit(1)
                                    Text(image.sizeText + (imagePatches[image.relativePath] != nil ? " • Đã thay ✓" : ""))
                                        .font(.caption)
                                        .foregroundColor(imagePatches[image.relativePath] != nil ? .green : .secondary)
                                }
                                Spacer()
                                if imagePatches[image.relativePath] != nil {
                                    Button {
                                        imagePatches.removeValue(forKey: image.relativePath)
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.caption)
                                    }
                                }
                                Button("Thay") {
                                    replacingImage = image
                                    showPhotoPicker = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
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

                Section(report.isTipa ? "Xuất TIPA" : "Xuất IPA") {
                    Text(report.isTipa
                        ? "TIPA giữ nguyên chữ ký gốc — cài qua TrollStore."
                        : "IPA xuất ra chưa được ký — mở bằng ZheeSign để ký & cài đặt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        exportPatchedIPA()
                    } label: {
                        Label(report.isTipa ? "Xuất TIPA đã chỉnh sửa" : "Xuất IPA đã chỉnh sửa", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasEdits || isExporting || report.workDir == nil)
                    if isExporting {
                        ZheeSlimProgressBar(text: "Đang áp patch & đóng gói…")
                    }
                    if let exportedURL {
                        ShareLink(item: exportedURL) {
                            Label(report.isTipa ? "Chia sẻ TIPA đã sửa" : "Chia sẻ IPA đã sửa", systemImage: "square.and.arrow.up")
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
        .toolbar(.hidden, for: .tabBar)
        .alert(completionAlertTitle, isPresented: $showCompletionAlert) {
            Button("Đã rõ", role: .cancel) { showCompletionAlert = false }
        } message: {
            Text(completionAlertMessage)
        }
        .onAppear { restoreSessionIfNeeded() }
        .onReceive(ZheeIPAAnalyzerSession.shared.$revision) { _ in restoreSessionIfNeeded() }
        .onChange(of: patches) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.patches = patches
            session.bump()
        }
        .onChange(of: imagePatches) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.imagePatches = imagePatches
            session.bump()
        }
        .onChange(of: editBundleID) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.editBundleID = editBundleID
            session.bump()
        }
        .onChange(of: editVersion) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.editVersion = editVersion
            session.bump()
        }
        .onChange(of: editBuild) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.editBuild = editBuild
            session.bump()
        }
        .onChange(of: exportMessage) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.exportMessage = exportMessage
            session.bump()
        }
        .onChange(of: exportedURL) { _ in
            let session = ZheeIPAAnalyzerSession.shared
            session.exportedURL = exportedURL
            session.bump()
        }
        .sheet(isPresented: $showPicker) {
            ZheeDocumentPicker(contentTypes: [UTType.ipa, UTType.tipa]) { url in
                showPicker = false
                if let url {
                    analyze(url: url)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $previewNode) { node in
            if let workDir = report?.workDir {
                ZheeFilePreviewView(
                    fileURL: workDir.appendingPathComponent(node.path),
                    fileName: node.name
                )
            }
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { newItem in
            guard let newItem, let target = replacingImage else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    imagePatches[target.relativePath] = data
                }
                photoItem = nil
                replacingImage = nil
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
        // The picker copy (asCopy) lives in tmp and the system may purge
        // it after dismissal — the multi-second scan outlives it, so a
        // late file-size read saw a deleted file ("—"). Copy to a stable
        // temp path we own before analyzing.
        let displayName = url.lastPathComponent
        var url = url
        let stableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZheePick_\(UUID().uuidString)_\(displayName)")
        if (try? FileManager.default.copyItem(at: url, to: stableURL)) != nil {
            url = stableURL
        }
        if let oldDir = report?.workDir {
            try? FileManager.default.removeItem(at: oldDir)
        }
        // Drop the previous session (incl. its workDir) so a stale
        // completion can never resurrect it; runID drops stale results.
        let myRun = UUID()
        // Giu app chay nen (audio im lang) cho toi khi quet xong.
        ZheeBackgroundKeeper.shared.start()
        ZheeScanNotifier.requestAuthorization()
        analysisRunID = myRun
        let session = ZheeIPAAnalyzerSession.shared
        session.runID = myRun
        if let oldDir = session.report?.workDir {
            try? FileManager.default.removeItem(at: oldDir)
        }
        session.report = nil
        session.patches = [:]
        session.imagePatches = [:]
        session.exportMessage = nil
        session.exportedURL = nil
        session.isAnalyzing = true
        session.progressText = "Đang chuẩn bị…"
        session.progressStep = 0
        session.progressLog = [(Date(), "Bắt đầu phân tích \(displayName)")]
        session.bump()
        isAnalyzing = true
        errorMessage = nil
        report = nil
        copiedURL = nil
        patches = [:]
        imagePatches = [:]
        editBundleID = ""
        editVersion = ""
        editBuild = ""
        origBundleID = ""
        origVersion = ""
        origBuild = ""
        exportMessage = nil
        exportedURL = nil
        progressText = "Đang chuẩn bị…"
        progressStep = 0
        progressLog = [(Date(), "Bắt đầu phân tích \(displayName)")]
        let startedAt = Date()
        // Picker đã copy file về local (asCopy), dùng trực tiếp được
        ZheeIPAAnalyzer().analyze(ipaURL: url, displayName: displayName, onProgress: { step in
            DispatchQueue.main.async {
                progressText = step
                progressStep = Self.stageIndex(for: step)
                progressLog.append((Date(), step))
                let session = ZheeIPAAnalyzerSession.shared
                session.progressText = step
                session.progressStep = Self.stageIndex(for: step)
                session.progressLog = progressLog
                session.bump()
            }
        }) { result in
            // Ket thuc giu nen (ke ca khi completion bi stale-drop).
            defer { DispatchQueue.main.async { ZheeBackgroundKeeper.shared.stop() } }
            try? FileManager.default.removeItem(at: url)
            // Stale run (a newer analysis started): drop the result.
            guard analysisRunID == myRun,
                  ZheeIPAAnalyzerSession.shared.runID == myRun else { return }
            switch result {
            case .success(let result):
                progressLog.append((Date(), String(format: "Hoàn tất trong %.1fs", Date().timeIntervalSince(startedAt))))
                progressText = "Đã quét xong"
                showProgressDetails = false
                completionAlertTitle = "Đã quét xong \(result.appName)"
                completionAlertMessage = "\(result.links.count) link, \(result.secrets.count) secret, \(result.warnings.count) cảnh báo — hoàn tất trong \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s"
                showCompletionAlert = true
                ZheeScanNotifier.post(title: completionAlertTitle, body: completionAlertMessage)
                report = result
                origBundleID = result.bundleID == "—" ? "" : result.bundleID
                origVersion = result.version == "—" ? "" : result.version
                origBuild = result.build == "—" ? "" : result.build
                editBundleID = origBundleID
                editVersion = origVersion
                editBuild = origBuild
                imagePatches = [:]
                isAnalyzing = false
                // Keep the finished analysis in the session so going
                // back does not lose it.
                let session = ZheeIPAAnalyzerSession.shared
                session.patches = patches
                session.imagePatches = imagePatches
                session.editBundleID = editBundleID
                session.editVersion = editVersion
                session.editBuild = editBuild
                session.origBundleID = origBundleID
                session.origVersion = origVersion
                session.origBuild = origBuild
                session.exportMessage = exportMessage
                session.exportedURL = exportedURL
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
                let session = ZheeIPAAnalyzerSession.shared
                session.isAnalyzing = false
                session.progressText = progressText
                session.progressStep = progressStep
                session.progressLog = progressLog
                session.bump()
            }
        }
    }

    /// Restores the last finished analysis from the session (e.g. after
    /// going back and returning). Drops it if the extracted folder is gone.
    private func restoreSessionIfNeeded() {
        let session = ZheeIPAAnalyzerSession.shared
        // Adopt in-flight (or last) progress first: going back mid-scan
        // and returning must show the live progress, not a dead empty
        // screen with an enabled picker that would kill the running scan.
        if progressLog.isEmpty {
            isAnalyzing = session.isAnalyzing
            progressText = session.progressText
            progressStep = session.progressStep
            progressLog = session.progressLog
            showProgressDetails = session.isAnalyzing
        }
        guard report == nil else { return }
        guard let saved = session.report else { return }
        if let dir = saved.workDir, !FileManager.default.fileExists(atPath: dir.path) {
            session.report = nil
            session.patches = [:]
            session.imagePatches = [:]
            session.isAnalyzing = false
            session.progressText = ""
            session.progressStep = 0
            session.progressLog = []
            return
        }
        report = saved
        patches = session.patches
        imagePatches = session.imagePatches
        editBundleID = session.editBundleID
        editVersion = session.editVersion
        editBuild = session.editBuild
        origBundleID = session.origBundleID
        origVersion = session.origVersion
        origBuild = session.origBuild
        exportMessage = session.exportMessage
        if let url = session.exportedURL, FileManager.default.fileExists(atPath: url.path) {
            exportedURL = url
        }
    }

    private func flowNode(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func categoryColor(_ category: ZheeLinkCategory) -> Color {
        switch category {
        case .telegram: return .blue
        case .discord: return .indigo
        case .api: return .orange
        case .firebase: return .yellow
        case .webhook: return .purple
        case .social: return .pink
        case .other: return .gray
        }
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    private func flowArrow() -> some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
    }

    private func fileTreeView(node: ZheeFileNode) -> AnyView {
        if node.isDir {
            return AnyView(
                DisclosureGroup {
                    ForEach(node.children) { child in
                        fileTreeView(node: child)
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(node.name)
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(node.sizeText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            )
        }
        return AnyView(
            Button {
                previewNode = node
            } label: {
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                    Text(node.name)
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text(node.sizeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        )
    }

    private var hasEdits: Bool {
        if !patches.isEmpty || !imagePatches.isEmpty { return true }
        return editBundleID != origBundleID || editVersion != origVersion || editBuild != origBuild
    }

    /// "AppIcon76x76@2x~ipad.png" -> "AppIcon76x76"; nil for non-AppIcon files.
    private static func iconBaseName(for relativePath: String) -> String? {
        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent
        guard fileName.lowercased().hasPrefix("appicon") else { return nil }
        var name = (fileName as NSString).deletingPathExtension
        var stripped = true
        while stripped {
            stripped = false
            for suffix in ["~ipad", "~iphone", "@3x", "@2x"] where name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                stripped = true
            }
        }
        return name.isEmpty ? nil : name
    }

    private func exportPatchedIPA() {
        guard let report, let workDir = report.workDir, hasEdits else { return }
        isExporting = true
        exportMessage = nil
        exportedURL = nil
        let ext = report.isTipa ? "tipa" : "ipa"
        let baseName = report.fileName.replacingOccurrences(of: ".\(ext)", with: "")
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName)-patched.\(ext)")
        let currentPatches = patches
        let currentImages = imagePatches
        let plistEdits = (bundleID: editBundleID != origBundleID ? editBundleID : nil,
                          version: editVersion != origVersion ? editVersion : nil,
                          build: editBuild != origBuild ? editBuild : nil)
        let keepSignature = report.isTipa
        // Giu app chay nen cho toi khi dong goi xong.
        ZheeBackgroundKeeper.shared.start()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var changed = 0
                if !currentPatches.isEmpty {
                    changed += try ZheeIPAPatcher.applyPatches(workDir: workDir, replacements: currentPatches)
                }
                if plistEdits.bundleID != nil || plistEdits.version != nil || plistEdits.build != nil {
                    try ZheeIPAPatcher.applyPlistEdits(workDir: workDir, bundleID: plistEdits.bundleID, version: plistEdits.version, build: plistEdits.build)
                    changed += 1
                }
                if !currentImages.isEmpty {
                    try ZheeIPAPatcher.applyImagePatches(workDir: workDir, images: currentImages)
                    changed += currentImages.count
                }
                // Catalog-icon apps: point the plist at the replaced loose
                // AppIcon files so SpringBoard shows the new icon.
                let replacedIconNames = currentImages.keys.compactMap { Self.iconBaseName(for: $0) }
                if try ZheeIPAPatcher.applyIconFallback(workDir: workDir, replacedIconBaseNames: replacedIconNames) {
                    changed += 1
                }
                try ZheeIPAPatcher.repack(workDir: workDir, outputURL: outURL, stripSignature: !keepSignature)
                DispatchQueue.main.async {
                    ZheeBackgroundKeeper.shared.stop()
                    exportedURL = outURL
                    exportMessage = keepSignature
                        ? "Đã xuất TIPA — sửa \(changed) mục. Giữ nguyên chữ ký gốc, cài qua TrollStore."
                        : "Đã xuất IPA — sửa \(changed) mục. IPA chưa được ký, mở bằng ZheeSign để ký & cài."
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    ZheeBackgroundKeeper.shared.stop()
                    exportMessage = "Lỗi: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
}

/// Maps an analyzer progress message to the stage timeline index.
extension ZheeIPAAnalyzerView {
    fileprivate static func stageIndex(for text: String) -> Int {
        if text.contains("quét") { return 4 }
        if text.contains("Mach-O") { return 3 }
        if text.contains("provisioning") { return 2 }
        if text.contains("Info.plist") { return 1 }
        return 0
    }
}

/// Pretty analyze progress: pulsing status + gradient bar with shine +
/// stage timeline (done = green check, current = pulsing dot).
/// Shared by the IPA / APK / Hex analyzers.
struct ZheeAnalyzeProgressView: View {
    let step: Int
    let text: String
    let stages: [String]
    @State private var pulse = false
    @State private var shineX: CGFloat = -60

    private var fraction: CGFloat { CGFloat(min(step + 1, stages.count)) / CGFloat(max(stages.count, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 1.4 : 1)
                    .opacity(pulse ? 0.5 : 1)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                Text(text.isEmpty ? "Đang phân tích…" : text)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    ZStack(alignment: .leading) {
                        Capsule().fill(
                            LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 50)
                            .offset(x: shineX)
                    }
                    .frame(width: geo.size.width * fraction)
                    .clipShape(Capsule())
                }
            }
            .frame(height: 8)
            ForEach(Array(stages.enumerated()), id: \.offset) { i, label in
                HStack(spacing: 10) {
                    stageDot(i)
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(i == step ? .semibold : .regular)
                        .foregroundColor(i > step ? .secondary : .primary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shineX = 500
            }
        }
    }

    @ViewBuilder
    private func stageDot(_ i: Int) -> some View {
        if i < step {
            ZStack {
                Circle().fill(Color.green)
                ZheeOutlineIcon(.check, size: 11, color: .white)
            }
            .frame(width: 24, height: 24)
        } else if i == step {
            ZStack {
                Circle().stroke(Color.blue, lineWidth: 2)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 1.3 : 1)
                    .opacity(pulse ? 0.6 : 1)
            }
            .frame(width: 24, height: 24)
        } else {
            Circle()
                .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 24, height: 24)
        }
    }
}

/// Slim indeterminate progress bar for patch & repack.
private struct ZheeSlimProgressBar: View {
    let text: String
    @State private var slideX: CGFloat = -80

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: slideX)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                slideX = 320
            }
        }
    }
}

/// "Nhật ký tiến trình" section: every step with an HH:mm:ss timestamp.
/// Shared by the IPA / APK / Hex analyzers.
struct ZheeProgressLogView: View {
    let log: [(Date, String)]
    var showTitle = true

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        if showTitle {
            Section("Nhật ký tiến trình") {
                rows
            }
        } else {
            rows
        }
    }

    private var rows: some View {
        ForEach(log.indices, id: \.self) { i in
            HStack(alignment: .top, spacing: 8) {
                Text(Self.formatter.string(from: log[i].0))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Text(log[i].1)
                    .font(.caption)
            }
        }
    }
}
