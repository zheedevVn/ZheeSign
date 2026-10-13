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
	
	private let repoAPI = "https://api.github.com/repos/zheedevVn/ZheeSign/releases/tags/beta"
	private let manifestURL = "https://github.com/zheedevVn/ZheeSign/releases/download/beta/manifest.plist"
	
	var currentVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
	}
	
	func checkForUpdates() {
		guard !isChecking else { return }
		isChecking = true
		
		guard let url = URL(string: repoAPI) else {
			isChecking = false
			return
		}
		
		URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
			DispatchQueue.main.async {
				self?.isChecking = false
				guard let data = data,
				      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				      let body = json["body"] as? String else { return }
				
				// Parse version từ release notes hoặc tag
				self?.parseReleaseInfo(body: body)
			}
		}.resume()
	}
	
	private func parseReleaseInfo(body: String) {
		// Tìm version trong body (format: ## Commit: ... hoặc version trong notes)
		// Đơn giản: luôn coi như có update nếu body khác rỗng và khác lần check trước
		let lastSeen = UserDefaults.standard.string(forKey: "zhee_last_seen_update")
		if body != lastSeen {
			// Lấy version từ manifest hoặc hiển thị "Bản mới"
			self.latestVersion = "Bản mới"
			self.releaseNotes = body
			self.updateAvailable = true
		}
	}
	
	func installUpdate() {
		// Đánh dấu đã thấy
		if let notes = releaseNotes {
			UserDefaults.standard.set(notes, forKey: "zhee_last_seen_update")
		}
		
		// Mở itms-services để cài đặt OTA (ghi đè app cũ, không cần xóa)
		if let url = URL(string: "itms-services://?action=download-manifest&url=\(manifestURL)") {
			UIApplication.shared.open(url)
		}
	}
	
	func dismissUpdate() {
		if let notes = releaseNotes {
			UserDefaults.standard.set(notes, forKey: "zhee_last_seen_update")
		}
		updateAvailable = false
	}
}
