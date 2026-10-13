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
	
	private let manifestURL = "https://github.com/zheedevVn/ZheeSign/releases/download/beta/manifest.plist"
	
	var currentVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
	}
	
	func checkForUpdates() {
		guard !isChecking else { return }
		isChecking = true
		
		guard let url = URL(string: manifestURL) else {
			isChecking = false
			return
		}
		
		URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
			DispatchQueue.main.async {
				self?.isChecking = false
				guard let data = data,
				      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
				      let items = plist["items"] as? [[String: Any]],
				      let first = items.first,
				      let metadata = first["metadata"] as? [String: Any],
				      let remoteVersion = metadata["bundle-version"] as? String else {
					return
				}
				
				self?.compareVersions(remote: remoteVersion)
			}
		}.resume()
	}
	
	private func compareVersions(remote: String) {
		let current = currentVersion
		
		// So sánh version: chỉ hiện update khi remote mới hơn
		if isNewer(remote: remote, than: current) {
			self.latestVersion = remote
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
		if let url = URL(string: "itms-services://?action=download-manifest&url=\(manifestURL)") {
			UIApplication.shared.open(url)
		}
	}
	
	func dismissUpdate() {
		updateAvailable = false
	}
}
