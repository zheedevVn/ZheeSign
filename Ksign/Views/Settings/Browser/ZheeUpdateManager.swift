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
import UserNotifications

class ZheeUpdateManager: ObservableObject {
	static let shared = ZheeUpdateManager()
	
	@Published var latestVersion: String?
	@Published var updateAvailable = false
	@Published var isChecking = false
	@Published var releaseNotes: String?
	
	// File version.json trên nhánh main - đơn giản, luôn mới nhất
	private let versionURL = "https://raw.githubusercontent.com/zheedevVn/ZheeSign/main/version.json"
	private let ipaURL = "https://github.com/zheedevVn/ZheeSign/releases/download/beta/ZheeSign.ipa"
	
	// Lưu version đã thông báo để không spam
	private var notifiedVersion: String? {
		get { UserDefaults.standard.string(forKey: "zhee.notifiedVersion") }
		set { UserDefaults.standard.set(newValue, forKey: "zhee.notifiedVersion") }
	}
	
	var currentVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
	}
	
	/// Xin quyền thông báo (gọi 1 lần khi mở app)
	func requestNotificationPermission() {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
			// Gửi thông báo 1 lần cho mỗi version mới
			if notifiedVersion != remote {
				notifiedVersion = remote
				sendUpdateNotification(version: remote, notes: notes)
			}
		} else {
			self.latestVersion = nil
			self.updateAvailable = false
		}
	}
	
	/// Thông báo iOS kiểu rich notification khi có bản mới
	private func sendUpdateNotification(version: String, notes: String?) {
		let center = UNUserNotificationCenter.current()
		center.getNotificationSettings { settings in
			guard settings.authorizationStatus == .authorized else { return }
			
			let content = UNMutableNotificationContent()
			content.title = "ZheeSign có bản mới"
			content.subtitle = "Phiên bản \(version) đã sẵn sàng"
			content.body = notes?.isEmpty == false ? notes! : "Mở app để cập nhật ngay"
			content.sound = .default
			
			// Mở app khi bấm vào thông báo
			let request = UNNotificationRequest(
				identifier: "zhee.update.\(version)",
				content: content,
				trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
			)
			center.add(request)
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
	
	@Published var isDownloading = false
	@Published var downloadProgress: Double = 0
	@Published var downloadedFileURL: URL?
	@Published var downloadError: String?
	
	private var downloadTask: URLSessionDownloadTask?
	private var progressTimer: Timer?
	
	// Tai IPA ve may roi mo bang app cai dat (TrollStore/ESign...)
	// itms-services khong dung duoc vi IPA unsigned
	func downloadUpdate() {
		guard !isDownloading else { return }
		downloadError = nil
		downloadedFileURL = nil
		
		guard let url = URL(string: ipaURL) else {
			downloadError = "URL không hợp lệ"
			return
		}
		
		isDownloading = true
		downloadProgress = 0
		
		let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
			DispatchQueue.main.async {
				self?.progressTimer?.invalidate()
				self?.progressTimer = nil
				self?.isDownloading = false
				
				if let error = error {
					self?.downloadError = error.localizedDescription
					return
				}
				guard let tempURL = tempURL else {
					self?.downloadError = "Tải thất bại"
					return
				}
				
				let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
				let fileName = "ZheeSign-\(self?.latestVersion ?? "new").ipa"
				let dest = docs.appendingPathComponent(fileName)
				try? FileManager.default.removeItem(at: dest)
				do {
					try FileManager.default.moveItem(at: tempURL, to: dest)
					self?.downloadedFileURL = dest
					self?.downloadProgress = 1
				} catch {
					self?.downloadError = "Không lưu được file"
				}
			}
		}
		downloadTask = task
		
		// Cap nhat tien trinh
		progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
			DispatchQueue.main.async {
				self?.downloadProgress = task.progress.fractionCompleted
			}
		}
		task.resume()
	}
	
	func cancelDownload() {
		downloadTask?.cancel()
		progressTimer?.invalidate()
		progressTimer = nil
		isDownloading = false
		downloadProgress = 0
	}
	
	// Mo share sheet de cai dat bang TrollStore / ESign / Sideloadly
	func shareDownloadedFile() {
		guard let url = downloadedFileURL else { return }
		let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
		guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		      let root = scene.windows.first?.rootViewController else { return }
		var top = root
		while let p = top.presentedViewController { top = p }
		if let pop = avc.popoverPresentationController {
			pop.sourceView = top.view
			pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
			pop.permittedArrowDirections = []
		}
		top.present(avc, animated: true)
	}
	
	// Gi lai tuong thich - gio goi download
	func installUpdate() {
		downloadUpdate()
	}
	
	func dismissUpdate() {
		updateAvailable = false
	}
}
