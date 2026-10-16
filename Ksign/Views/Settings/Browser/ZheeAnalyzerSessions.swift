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

import Foundation

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
    func bump() { revision += 1 }
}

final class ZheeAPKAnalyzerSession: ObservableObject {
    static let shared = ZheeAPKAnalyzerSession()
    @Published var revision = 0
    var runID = UUID()
    var report: ZheeAPKReport?
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
    func bump() { revision += 1 }
}
