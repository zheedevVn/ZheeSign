//
//  ResetView.swift
//  Feather
//
//  Created by samara on 19.06.2025.
//

import SwiftUI
import NimbleViews
import Nuke
import CoreData

// MARK: - View
struct ResetView: View {
	// MARK: Body
    var body: some View {
		NBList( ("Đặt lại")) {
			_cache()
			_coredata()
			_all()
		}
    }
	
	private func _cacheSize() -> String {
		var totalCacheSize = URLCache.shared.currentDiskUsage
		if let nukeCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			totalCacheSize += nukeCache.totalSize
		}
		return "\(ByteCountFormatter.string(fromByteCount: Int64(totalCacheSize), countStyle: .file))"
	}
	
	static func resetAlert(
		title: String,
		message: String = "",
		action: @escaping () -> Void
	) {
		let action = UIAlertAction(
			title:  ("继续"),
			style: .destructive
		) { _ in
			action()
			UIApplication.shared.suspendAndReopen()
		}
		
		let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad
		? .alert
		: .actionSheet
		
		var msg = ""
		if !message.isEmpty { msg = message + "\n" }
		msg.append( ("此操作不可撤销，是否继续？"))
	
		UIAlertController.showAlertWithCancel(
			title: title,
			message: msg,
			style: style,
			actions: [action]
		)
	}
}

// MARK: - View extension
extension ResetView {
	@ViewBuilder
	private func _cache() -> some View {
		Section {
			Button("Xóa cache công việc", systemImage: "xmark.rectangle.portrait") {
				Self.resetAlert(title: "Xóa cache công việc") {
					Self.clearWorkCache()
				}
			}
			
			Button("Xóa cache mạng", systemImage: "xmark.rectangle.portrait") {
				Self.resetAlert(
					title: "Xóa cache mạng",
					message: _cacheSize()
				) {
					Self.clearNetworkCache()
				}
			}
		}
	}
	
	@ViewBuilder
	private func _coredata() -> some View {
		Section {
			Button("Đặt lại nguồn", systemImage: "xmark.circle") {
				Self.resetAlert(
					title: "Xóa ứng dụng đã ký",
					message: Storage.shared.countContent(for: AltSource.self)
				) {
					Self.resetSources()
				}
			}
			
			Button("Xóa ứng dụng đã ký", systemImage: "xmark.circle") {
				Self.resetAlert(
					title: "Xóa ứng dụng đã ký",
					message: Storage.shared.countContent(for: Signed.self)
				) {
					Self.deleteSignedApps()
				}
			}
			
			Button("Xóa ứng dụng đã nhập", systemImage: "xmark.circle") {
				Self.resetAlert(
					title: "Xóa ứng dụng đã nhập",
					message: Storage.shared.countContent(for: Imported.self)
				) {
					Self.deleteImportedApps()
				}
			}
			
			Button("Đặt lại chứng chỉ", systemImage: "xmark.circle") {
				Self.resetAlert(
					title: "Đặt lại chứng chỉ",
					message: Storage.shared.countContent(for: CertificatePair.self)
				) {
					Self.resetCertificates()
				}
			}
		}
	}
	
	@ViewBuilder
	private func _all() -> some View {
		Section {
			Button("Đặt lại cài đặt", systemImage: "xmark.octagon") {
				Self.resetAlert(title: "Đặt lại cài đặt") {
					Self.resetUserDefaults()
				}
			}
			
			Button("Đặt lại tất cả", systemImage: "xmark.octagon") {
				Self.resetAlert(title: "Đặt lại tất cả") {
					Self.resetAll()
				}
			}
		}
		.foregroundStyle(.red)
	}
}

// MARK: - View extension: reset
extension ResetView {
	static func clearWorkCache() {
		let fileManager = FileManager.default
		let tmpDirectory = fileManager.temporaryDirectory
		
		if let files = try? fileManager.contentsOfDirectory(atPath: tmpDirectory.path()) {
			for file in files {
				try? fileManager.removeItem(atPath: tmpDirectory.appendingPathComponent(file).path())
			}
		}
	}
	
	static func clearNetworkCache() {
		URLCache.shared.removeAllCachedResponses()
		HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
		
		if let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			dataCache.removeAll()
		}
		
		if let imageCache = ImagePipeline.shared.configuration.imageCache as? Nuke.ImageCache {
			imageCache.removeAll()
		}
	}
	
	static func resetSources() {
		Storage.shared.clearContext(request: AltSource.fetchRequest())
	}
	
	static func deleteSignedApps() {
		Storage.shared.clearContext(request: Signed.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.signed)
	}
	
	static func deleteImportedApps() {
		Storage.shared.clearContext(request: Imported.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.unsigned)
	}
	
	static func resetCertificates(resetAll: Bool = false) {
		if !resetAll { UserDefaults.standard.set(0, forKey: "feather.selectedCert") }
		Storage.shared.clearContext(request: CertificatePair.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.certificates)
	}
	
	static func resetUserDefaults() {
		UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
	}
	
	static func resetAll() {
		clearWorkCache()
		clearNetworkCache()
		resetSources()
		deleteSignedApps()
		deleteImportedApps()
		resetCertificates(resetAll: true)
		resetUserDefaults()
	}
}
