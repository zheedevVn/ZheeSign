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
	private static let expectedVersion = "1.7.39"
	private static let expectedBuild = "1"
	
	private static let banKey = "zhee.tamper.ban"
	private static let banVersionKey = "zhee.tamper.banVersion"
	
	// MARK: - Ban
	
	/// Đã bị ban chưa
	static var isBanned: Bool {
		UserDefaults.standard.bool(forKey: banKey)
	}
	
	/// Ban vĩnh viễn — lưu kèm version để bản mới gỡ được
	private static func ban() {
		UserDefaults.standard.set(true, forKey: banKey)
		UserDefaults.standard.set(expectedVersion, forKey: banVersionKey)
		UserDefaults.standard.synchronize()
		// Lưu thêm vào Keychain để xóa app vẫn ban (cùng version)
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: "zhee.ban",
			kSecValueData as String: expectedVersion.data(using: .utf8)!
		]
		SecItemDelete(query as CFDictionary)
		SecItemAdd(query as CFDictionary, nil)
	}
	
	/// Gỡ ban — khi bản mới khác version bị ban
	private static func clearBan() {
		UserDefaults.standard.removeObject(forKey: banKey)
		UserDefaults.standard.removeObject(forKey: banVersionKey)
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: "zhee.ban"
		]
		SecItemDelete(query as CFDictionary)
	}
	
	/// Check Keychain có bị ban không
	private static var isKeychainBanned: Bool {
		keychainBanData() != nil
	}
	
	/// Version đã bị ban
	private static var bannedVersion: String? {
		if let data = keychainBanData(),
		   let str = String(data: data, encoding: .utf8) {
			return str
		}
		return UserDefaults.standard.string(forKey: banVersionKey)
	}
	
	private static func keychainBanData() -> Data? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: "zhee.ban",
			kSecReturnData as String: true
		]
		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		guard status == errSecSuccess else { return nil }
		return result as? Data
	}
	
	// MARK: - Kiểm tra
	
	/// Chạy ngay khi app khởi động — sai là crash luôn
	static func verifyOrCrash() {
		// Bản mới khác version bị ban → gỡ ban (phục hồi)
		if isBanned || isKeychainBanned {
			if bannedVersion != expectedVersion {
				clearBan()
			} else {
				crashNow()
			}
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
		
		// NOTE: Đã bỏ check Info.plist file + dylib — 2 check này dễ nhận nhầm
		// (đường dẫn /var vs /private/var, file plist đọc lỗi) gây ban oan.
		// Chỉ giữ check bundle ID + version từ hệ thống, đủ chặn đổi bundle/ver.
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
