//
//  ZheeAnalyzerSessions.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 16/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Analyzer state that survives the view being popped: tapping back no
//  longer loses the report + edits. The IPA session owns the extracted
//  workDir — the view no longer deletes it on disappear; it is deleted
//  when a new analysis starts.
//
//  `revision` is bumped after every batch of session writes; views
//  observe it to adopt a report that finished while they were gone.
//  `runID` drops stale completions when a newer analysis started.

import Combine
import Foundation
import UIKit
import UserNotifications

/// Thong bao khi quet xong ma app dang o nen. Alert trong app chi hien
/// khi man hinh analyzer dang mo, nen khi app o nen thi dung notification.
enum ZheeScanNotifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(title: String, body: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "zhee-scan-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}

final class ZheeIPAAnalyzerSession: ObservableObject {
    static let shared = ZheeIPAAnalyzerSession()
    @Published var revision = 0
    var runID = UUID()
    var report: ZheeIPAReport?
    var patches: [String: String] = [:]
    var imagePatches: [String: Data] = [:]
    var editBundleID = ""
    var editVersion = ""
    var editBuild = ""
    var origBundleID = ""
    var origVersion = ""
    var origBuild = ""
    var exportMessage: String?
    var exportedURL: URL?
    // In-flight progress: kept here (not in the view) so going back
    // mid-scan and returning still shows the live progress instead
    // of a dead empty screen.
    var isAnalyzing = false
    var progressText = ""
    var progressStep = 0
    var progressLog: [(Date, String)] = []
    func bump() { revision += 1 }
}

final class ZheeAPKAnalyzerSession: ObservableObject {
    static let shared = ZheeAPKAnalyzerSession()
    @Published var revision = 0
    var runID = UUID()
    var report: ZheeAPKReport?
    var isAnalyzing = false
    var progressText = ""
    var progressStep = 0
    var progressLog: [(Date, String)] = []
    func bump() { revision += 1 }
}

final class ZheeHexAnalyzerSession: ObservableObject {
    static let shared = ZheeHexAnalyzerSession()
    @Published var revision = 0
    var runID = UUID()
    var fileName = ""
    var fileSizeText = ""
    var fileData: Data?
    var strings: [String] = []
    var links: [ZheeLinkItem] = []
    var secrets: [ZheeSecretItem] = []
    var isAnalyzing = false
    var progressText = ""
    var progressStep = 0
    var progressLog: [(Date, String)] = []
    func bump() { revision += 1 }
}
