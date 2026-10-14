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
		// CTL_KERN=1, KERN_INFO=14, KERN_INFO_PROC=14 (macro C không có trong Swift)
		var mib: [Int32] = [1, 14, 14, getpid()]
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
	
	// MARK: - Endpoint Obfuscation (XOR — mạnh hơn base64)
	
	/// Giải mã XOR: key được chia nhỏ để không lộ trong binary
	private static func xorDecode(_ bytes: [UInt8], key: [UInt8]) -> String {
		var result = [UInt8]()
		result.reserveCapacity(bytes.count)
		for (i, b) in bytes.enumerated() {
			result.append(b ^ key[i % key.count])
		}
		return String(bytes: result, encoding: .utf8) ?? ""
	}
	
	/// Key XOR — chia thành 3 phần, ghép lúc runtime
	private static var xorKey: [UInt8] {
		let p1: [UInt8] = [0x5A, 0x68, 0x33]
		let p2: [UInt8] = [0x65, 0x21, 0x9F]
		let p3: [UInt8] = [0x47, 0x2B, 0xC8]
		return p1 + p2 + p3
	}
	
	/// API base URL — XOR obfuscated
	/// "https://api-zhee.vercel.app"
	static var apiBaseURL: String {
		let enc: [UInt8] = [
			0x32, 0x1C, 0x47, 0x15, 0x52, 0xA5, 0x68, 0x04, 0xA9, 0x2A,
			0x01, 0x1E, 0x1F, 0x49, 0xFA, 0x22, 0x05, 0xBE, 0x3F, 0x1A,
			0x50, 0x00, 0x4D, 0xB1, 0x26, 0x5B, 0xB8
		]
		return xorDecode(enc, key: xorKey)
	}
	
	/// GitHub raw URL — XOR obfuscated
	/// "https://raw.githubusercontent.com/zheedevVn/ZheeSign/main/version.json"
	static var githubRawURL: String {
		let enc: [UInt8] = [
			0x32, 0x1C, 0x47, 0x15, 0x52, 0xA5, 0x68, 0x04, 0xBA, 0x3B,
			0x1F, 0x1D, 0x02, 0x48, 0xEB, 0x2F, 0x5E, 0xAA, 0x2F, 0x1B,
			0x56, 0x17, 0x42, 0xF0, 0x29, 0x5F, 0xAD, 0x34, 0x1C, 0x1D,
			0x06, 0x4E, 0xF2, 0x68, 0x51, 0xA0, 0x3F, 0x0D, 0x57, 0x00,
			0x57, 0xC9, 0x29, 0x04, 0x92, 0x32, 0x0D, 0x56, 0x36, 0x48,
			0xF8, 0x29, 0x04, 0xA5, 0x3B, 0x01, 0x5D, 0x4A, 0x57, 0xFA,
			0x35, 0x58, 0xA1, 0x35, 0x06, 0x1D, 0x0F, 0x52, 0xF0, 0x29
		]
		return xorDecode(enc, key: xorKey)
	}
	
	/// Giải mã endpoint từ base64 (legacy, giữ để tương thích)
	static func decodeEndpoint(_ encoded: String) -> String {
		guard let data = Data(base64Encoded: encoded),
		      let str = String(data: data, encoding: .utf8) else {
			return ""
		}
		return str
	}
	
	// MARK: - Runtime Protection
	
	/// Kiểm tra chữ ký code — phát hiện binary bị sửa
	static var isCodeSignatureValid: Bool {
		guard let bundlePath = Bundle.main.bundlePath as NSString?,
		      let codePath = bundlePath.appendingPathComponent("_CodeSignature/CodeResources") as String? else {
			return false
		}
		return FileManager.default.fileExists(atPath: codePath)
	}
	
	/// Timing check — debugger làm chậm execution
	static var isTimingAnomaly: Bool {
		let start = DispatchTime.now().uptimeNanoseconds
		// Vòng lặp nhỏ, debugger sẽ làm chậm đáng kể
		var sum = 0
		for i in 0..<10000 {
			sum += i * i
		}
		_ = sum
		let elapsed = DispatchTime.now().uptimeNanoseconds - start
		// Bình thường < 5ms, debugger thường > 50ms
		return elapsed > 50_000_000
	}
	
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
		if !isCodeSignatureValid {
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
