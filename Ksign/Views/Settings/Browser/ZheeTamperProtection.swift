//
//  ZheeTamperProtection.swift
//  ZheeSign
//
//  Chống giả mạo: đổi bundle ID / version / sửa file = ban + crash ngay.
//  © 2026 Hồ Đức Minh
//

import Foundation
import UIKit

/// Chống giả mạo siêu mạnh — phát hiện là crash, không thông báo
enum ZheeTamperProtection {
	
	// MARK: - Giá trị gốc (đổi khi bump version)
	private static let expectedBundleID = "vn.zheedev.zheesign"
	private static let expectedVersion = "1.7.29"
	private static let expectedBuild = "1"
	
	private static let banKey = "zhee.tamper.ban"
	
	// MARK: - Ban
	
	/// Đã bị ban chưa
	static var isBanned: Bool {
		UserDefaults.standard.bool(forKey: banKey)
	}
	
	/// Ban vĩnh viễn — lưu vào Keychain (xóa app cài lại vẫn ban)
	private static func ban() {
		UserDefaults.standard.set(true, forKey: banKey)
		UserDefaults.standard.synchronize()
		// Lưu thêm vào Keychain để xóa app vẫn ban
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: "zhee.ban",
			kSecValueData as String: "1".data(using: .utf8)!
		]
		SecItemDelete(query as CFDictionary)
		SecItemAdd(query as CFDictionary, nil)
	}
	
	/// Check Keychain có bị ban không
	private static var isKeychainBanned: Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: "zhee.ban",
			kSecReturnData as String: true
		]
		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		return status == errSecSuccess
	}
	
	// MARK: - Kiểm tra
	
	/// Chạy ngay khi app khởi động — sai là crash luôn
	static func verifyOrCrash() {
		// Đã bị ban trước đó → crash ngay
		if isBanned || isKeychainBanned {
			crashNow()
		}
		
		// 1. Check bundle ID
		if Bundle.main.bundleIdentifier != expectedBundleID {
			ban()
			crashNow()
		}
		
		// 2. Check version
		let info = Bundle.main.infoDictionary
		let version = info?["CFBundleShortVersionString"] as? String ?? ""
		if version != expectedVersion {
			ban()
			crashNow()
		}
		
		// 3. Check build number không bị sửa
		let build = info?["CFBundleVersion"] as? String ?? ""
		if build != expectedBuild && !build.isEmpty {
			// Build có thể đổi khi re-sign, chỉ check version thôi
			// (không ban vì build)
		}
		
		// 4. Check file Info.plist còn nguyên
		if !isInfoPlistIntact() {
			ban()
			crashNow()
		}
		
		// 5. Check không có dylib lạ inject
		if hasInjectedDylib() {
			ban()
			crashNow()
		}
		
		// 6. Check chữ ký code
		if !ZheeSecurity.isCodeSignatureValid {
			ban()
			crashNow()
		}
	}
	
	/// Info.plist có bị sửa không
	private static func isInfoPlistIntact() -> Bool {
		guard let plistPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
		      let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
		      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
			return false
		}
		// Bundle ID trong plist phải khớp
		let plistBundleID = plist["CFBundleIdentifier"] as? String ?? ""
		if plistBundleID != expectedBundleID {
			return false
		}
		// Version trong plist phải khớp
		let plistVersion = plist["CFBundleShortVersionString"] as? String ?? ""
		if plistVersion != expectedVersion {
			return false
		}
		return true
	}
	
	/// Có dylib lạ inject không (troll / hook)
	private static func hasInjectedDylib() -> Bool {
		let count = _dyld_image_count()
		let allowedPrefixes = [
			"/System/Library/",
			"/usr/lib/",
			"/usr/lib/system/",
			Bundle.main.bundlePath
		]
		for i in 0..<count {
			if let name = _dyld_get_image_name(i) {
				let libPath = String(cString: name)
				// Bỏ qua thư viện hệ thống và app
				var isAllowed = false
				for prefix in allowedPrefixes {
					if libPath.hasPrefix(prefix) {
						isAllowed = true
						break
					}
				}
				// Thư viện ngoài hệ thống + ngoài app = inject
				if !isAllowed {
					// Cho phép một số framework hợp lệ
					if libPath.contains("SwiftUI") || libPath.contains("Foundation") ||
					   libPath.contains("UIKit") || libPath.contains("Core") {
						continue
					}
					return true
				}
			}
		}
		return false
	}
	
	// MARK: - Crash
	
	/// Crash ngay lập tức — SIGABRT, không thông báo
	@inline(__always)
	private static func crashNow() -> Never {
		// Ghi log ban rồi crash
		NSLog("[ZHEE] Tamper detected - terminating")
		// SIGABRT — crash thật, không phải thoát bình thường
		abort()
	}
}
