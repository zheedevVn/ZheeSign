//
//  ZheeSecurity.swift
//  ZheeSign
//
//  Chống dịch ngược, chống debug, chống dump — bảo vệ endpoint và logic.
//  © 2026 Hồ Đức Minh
//

import Foundation
import UIKit

/// Bảo mật app: chống debug, jailbreak, Frida, dump
enum ZheeSecurity {
	
	// MARK: - Anti-Debug
	
	/// Kiểm tra có debugger đang attach không
	static var isDebugged: Bool {
		var info = kinfo_proc()
		var mib: [Int32] = [CTL_KERN, KERN_INFO, KERN_INFO_PROC, getpid()]
		var size = MemoryLayout<kinfo_proc>.stride
		let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
		guard result == 0 else { return false }
		return (info.kp_proc.p_flag & P_TRACED) != 0
	}
	
	/// Kiểm tra có đang chạy trên máy jailbreak không
	static var isJailbroken: Bool {
		#if targetEnvironment(simulator)
		return false
		#else
		// Check các file chỉ có trên máy jailbreak
		let paths = [
			"/Applications/Cydia.app",
			"/Library/MobileSubstrate/MobileSubstrate.dylib",
			"/bin/bash",
			"/usr/sbin/sshd",
			"/etc/apt",
			"/private/var/lib/apt/",
			"/usr/bin/ssh"
		]
		for path in paths {
			if FileManager.default.fileExists(atPath: path) {
				return true
			}
		}
		// Check có ghi được ra ngoài sandbox không
		let testPath = "/private/jb-test-\(UUID().uuidString)"
		do {
			try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
			try FileManager.default.removeItem(atPath: testPath)
			return true
		} catch {
			// Không ghi được = không jailbreak (bình thường)
		}
		// Check dyld có inject thư viện lạ không
		let count = _dyld_image_count()
		for i in 0..<count {
			if let name = _dyld_get_image_name(i) {
				let libName = String(cString: name)
				if libName.contains("Substrate") ||
				   libName.contains("Frida") ||
				   libName.contains("Cydia") ||
				   libName.contains("cycript") {
					return true
				}
			}
		}
		return false
		#endif
	}
	
	/// Kiểm tra Frida / injection
	static var isFridaPresent: Bool {
		let count = _dyld_image_count()
		for i in 0..<count {
			if let name = _dyld_get_image_name(i) {
				let libName = String(cString: name).lowercased()
				if libName.contains("frida") ||
				   libName.contains("gadget") ||
				   libName.contains("cynject") {
					return true
				}
			}
		}
		// Check port Frida mặc định (27042)
		return canConnectTo(port: 27042)
	}
	
	private static func canConnectTo(port: UInt16) -> Bool {
		var addr = sockaddr_in()
		addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
		addr.sin_family = sa_family_t(AF_INET)
		addr.sin_port = port.bigEndian
		addr.sin_addr.s_addr = inet_addr("127.0.0.1")
		let sock = socket(AF_INET, SOCK_STREAM, 0)
		guard sock >= 0 else { return false }
		defer { close(sock) }
		let result = withUnsafePointer(to: &addr) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
			}
		}
		return result == 0
	}
	
	// MARK: - Endpoint Obfuscation
	
	/// Giải mã endpoint từ base64 (không để URL trần trong binary)
	static func decodeEndpoint(_ encoded: String) -> String {
		guard let data = Data(base64Encoded: encoded),
		      let str = String(data: data, encoding: .utf8) else {
			return ""
		}
		return str
	}
	
	/// API base URL — mã hóa base64 để không lộ trong strings
	static var apiBaseURL: String {
		// "https://api-zhee.vercel.app"
		decodeEndpoint("aHR0cHM6Ly9hcGktenhlZS52ZXJjZWwuYXBw")
	}
	
	/// GitHub raw URL — mã hóa
	static var githubRawURL: String {
		// "https://raw.githubusercontent.com/zheedevVn/ZheeSign/main/version.json"
		decodeEndpoint("aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3poZWVkZXZWbi9aaGVlU2lnbi9tYWluL3ZlcnNpb24uanNvbg==")
	}
	
	// MARK: - Runtime Protection
	
	/// Chạy kiểm tra bảo mật khi app khởi động
	/// Trả về true nếu an toàn, false nếu phát hiện tấn công
	static func validateEnvironment() -> Bool {
		#if DEBUG
		// Debug build thì bỏ qua (cho dev)
		return true
		#else
		if isDebugged {
			return false
		}
		if isFridaPresent {
			return false
		}
		// Jailbreak thì vẫn cho chạy nhưng log (không chặn vì user tự dùng)
		return true
		#endif
	}
	
	/// Xóa dữ liệu nhạy cảm khỏi bộ nhớ khi vào background
	static func clearSensitiveData() {
		// Xóa clipboard nếu chứa token
		if let text = UIPasteboard.general.string,
		   text.count > 20 && (text.contains("ghp_") || text.contains("Bearer") || text.contains("token")) {
			UIPasteboard.general.string = ""
		}
	}
}
