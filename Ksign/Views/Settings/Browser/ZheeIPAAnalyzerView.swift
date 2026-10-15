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
    @State private var isAnalyzing = false
    @State private var progressText = ""
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
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        TextField("vn.example.app", text: $editBundleID)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        TextField("1.0", text: $editVersion)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        TextField("1", text: $editBuild)
                            .multilineTextAlignment(.trailing)
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
                        HStack {
                            ProgressView()
                            Text("Đang áp patch & đóng gói…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
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
        // Picker đã copy file về local (asCopy), dùng trực tiếp được
        ZheeIPAAnalyzer().analyze(ipaURL: url, displayName: url.lastPathComponent, onProgress: { step in
            DispatchQueue.main.async { progressText = step }
        }) { result in
            try? FileManager.default.removeItem(at: url)
            switch result {
            case .success(let result):
                report = result
                origBundleID = result.bundleID == "—" ? "" : result.bundleID
                origVersion = result.version == "—" ? "" : result.version
                origBuild = result.build == "—" ? "" : result.build
                editBundleID = origBundleID
                editVersion = origVersion
                editBuild = origBuild
                imagePatches = [:]
                isAnalyzing = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                isAnalyzing = false
            }
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

    private func fileTreeView(node: ZheeFileNode) -> some View {
        Group {
            if node.isDir {
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
            } else {
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
        }
    }

    private var hasEdits: Bool {
        if !patches.isEmpty || !imagePatches.isEmpty { return true }
        return editBundleID != origBundleID || editVersion != origVersion || editBuild != origBuild
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
                try ZheeIPAPatcher.repack(workDir: workDir, outputURL: outURL, stripSignature: !keepSignature)
                DispatchQueue.main.async {
                    exportedURL = outURL
                    exportMessage = keepSignature
                        ? "Đã xuất TIPA — sửa \(changed) mục. Giữ nguyên chữ ký gốc, cài qua TrollStore."
                        : "Đã xuất IPA — sửa \(changed) mục. IPA chưa được ký, mở bằng ZheeSign để ký & cài."
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
