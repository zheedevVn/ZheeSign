//
//  ZheeAppLockManager.swift
//  ZheeSign
//
//  Khóa ứng dụng bằng Face ID / Touch ID / mã PIN.
//  © 2026 Hồ Đức Minh
//

import Foundation
import LocalAuthentication
import Security
import CryptoKit
import SwiftUI

final class ZheeAppLockManager: ObservableObject {
	static let shared = ZheeAppLockManager()
	
	@Published var isLocked = false
	
	private let defaults = UserDefaults.standard
	private let pinKey = "zhee.applock.pin"
	
	@Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: "zhee.applock.enabled") {
		didSet { defaults.set(isEnabled, forKey: "zhee.applock.enabled") }
	}
	
	@Published var useBiometrics: Bool = UserDefaults.standard.bool(forKey: "zhee.applock.biometrics") {
		didSet { defaults.set(useBiometrics, forKey: "zhee.applock.biometrics") }
	}
	
	/// Thời gian chờ tự khóa (giây). 0 = ngay lập tức
	@Published var lockDelay: TimeInterval = UserDefaults.standard.double(forKey: "zhee.applock.delay") {
		didSet { defaults.set(lockDelay, forKey: "zhee.applock.delay") }
	}
	
	var hasPIN: Bool {
		keychainLoad() != nil
	}
	
	var biometricType: LABiometryType {
		let ctx = LAContext()
		_ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
		return ctx.biometryType
	}
	
	var biometricName: String {
		switch biometricType {
		case .faceID: return "Face ID"
		case .touchID: return "Touch ID"
		default: return "sinh trắc học"
		}
	}
	
	var canUseBiometrics: Bool {
		let ctx = LAContext()
		return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
	}
	
	private init() {
		// Khóa ngay từ lúc mở app nếu đã bật - không để lộ nội dung trước
		if isEnabled && hasPIN {
			_isLocked = Published(initialValue: true)
		}
	}
	
	// MARK: - PIN (lưu hash trong Keychain)
	
	func setPIN(_ pin: String) {
		let hash = SHA256.hash(data: Data(pin.utf8)).map { String(format: "%02x", $0) }.joined()
		keychainSave(hash)
	}
	
	func verifyPIN(_ pin: String) -> Bool {
		guard let stored = keychainLoad() else { return false }
		let hash = SHA256.hash(data: Data(pin.utf8)).map { String(format: "%02x", $0) }.joined()
		return hash == stored
	}
	
	func clearPIN() {
		keychainDelete()
	}
	
	// MARK: - Khóa / mở
	
	func lock() {
		guard isEnabled, hasPIN else { return }
		DispatchQueue.main.async { self.isLocked = true }
	}
	
	func unlock() {
		// Reset mốc thời gian khi mở khóa thành công - tránh appDidBecomeActive khóa lại ngay gây lặp vô tận
		defaults.set(Date().timeIntervalSince1970, forKey: "zhee.applock.lastbg")
		DispatchQueue.main.async { self.isLocked = false }
	}
	
	/// Gọi khi app vào foreground — khóa nếu quá thời gian chờ
	func appDidBecomeActive() {
		guard isEnabled, hasPIN, !isLocked else { return }
		let lastBG = defaults.double(forKey: "zhee.applock.lastbg")
		// Lần đầu mở app (chưa có lastbg) -> khóa ngay nếu bật
		if lastBG == 0 {
			lock()
			return
		}
		let elapsed = Date().timeIntervalSince(Date(timeIntervalSince1970: lastBG))
		if elapsed >= lockDelay {
			lock()
		}
	}
	
	func appDidEnterBackground() {
		defaults.set(Date().timeIntervalSince1970, forKey: "zhee.applock.lastbg")
	}
	
	// MARK: - Sinh trắc học
	
	func authenticateBiometric(completion: @escaping (Bool) -> Void) {
		let ctx = LAContext()
		ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
						   localizedReason: "Mở khóa ZheeSign") { success, _ in
			DispatchQueue.main.async { completion(success) }
		}
	}
	
	// MARK: - Keychain
	
	private func keychainSave(_ value: String) {
		keychainDelete()
		let data = Data(value.utf8)
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: pinKey,
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
		]
		SecItemAdd(query as CFDictionary, nil)
	}
	
	private func keychainLoad() -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: pinKey,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		var result: AnyObject?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			  let data = result as? Data else { return nil }
		return String(data: data, encoding: .utf8)
	}
	
	private func keychainDelete() {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: pinKey
		]
		SecItemDelete(query as CFDictionary)
	}
}
