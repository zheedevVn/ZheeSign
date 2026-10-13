//
//  ZheeUpdateManager.swift
//  ZheeSign
//
//  Kiểm tra và cài đặt cập nhật OTA — không cần xóa app.
//  © 2026 Hồ Đức Minh
//

import Foundation
import SwiftUI
import UIKit

class ZheeUpdateManager: ObservableObject {
	static let shared = ZheeUpdateManager()
	
	@Published var latestVersion: String?
	@Published var updateAvailable = false
	@Published var isChecking = false
	@Published var releaseNotes: String?
	
	// File version.json trên nhánh main - đơn giản, luôn mới nhất
	private let versionURL = "https://raw.githubusercontent.com/zheedevVn/ZheeSign/main/version.json"
	private let manifestURL = "https://github.com/zheedevVn/ZheeSign/releases/download/beta/manifest.plist"
	
	var currentVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
	}
	
	func checkForUpdates() {
		guard !isChecking else { return }
		isChecking = true
		
		// Thêm timestamp để tránh cache
		let urlString = versionURL + "?t=\(Int(Date().timeIntervalSince1970))"
		guard let url = URL(string: urlString) else {
			isChecking = false
			return
		}
		
		var request = URLRequest(url: url)
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		
		URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
			DispatchQueue.main.async {
				self?.isChecking = false
				guard let data = data,
				      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				      let remoteVersion = json["version"] as? String else {
					return
				}
				
				let notes = json["notes"] as? String
				self?.compareVersions(remote: remoteVersion, notes: notes)
			}
		}.resume()
	}
	
	private func compareVersions(remote: String, notes: String?) {
		let current = currentVersion
		
		if isNewer(remote: remote, than: current) {
			self.latestVersion = remote
			self.releaseNotes = notes
			self.updateAvailable = true
		} else {
			self.latestVersion = nil
			self.updateAvailable = false
		}
	}
	
	private func isNewer(remote: String, than current: String) -> Bool {
		let r = remote.split(separator: ".").compactMap { Int($0) }
		let c = current.split(separator: ".").compactMap { Int($0) }
		let maxLen = max(r.count, c.count)
		for i in 0..<maxLen {
			let rv = i < r.count ? r[i] : 0
			let cv = i < c.count ? c[i] : 0
			if rv > cv { return true }
			if rv < cv { return false }
		}
		return false
	}
	
	func installUpdate() {
		// Them timestamp de tranh iOS cache manifest cu
		let urlWithCache = "\(manifestURL)?t=\(Int(Date().timeIntervalSince1970))"
		if let encoded = urlWithCache.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
		   let url = URL(string: "itms-services://?action=download-manifest&url=\(encoded)") {
			UIApplication.shared.open(url)
		}
	}
	
	func dismissUpdate() {
		updateAvailable = false
	}
}
