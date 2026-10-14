//
//  ZheeBackgroundKeeper.swift
//  ZheeSign
//
//  Giữ app sống dưới nền bằng audio im lặng để Python chạy như server.
//  © 2026 Hồ Đức Minh
//

import AVFoundation
import UIKit

final class ZheeBackgroundKeeper: ObservableObject {
	static let shared = ZheeBackgroundKeeper()
	
	@Published var isKeepingAlive = false
	
	private var audioPlayer: AVAudioPlayer?
	private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
	
	private init() {}
	
	/// Bật giữ app chạy nền
	func start() {
		guard !isKeepingAlive else { return }
		
		do {
			// Cấu hình audio session để phát dưới nền
			try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			print("ZheeBackgroundKeeper: audio session lỗi: \(error)")
			return
		}
		
		// Tạo file audio im lặng 1s, lặp vô hạn
		if let silentURL = createSilentAudio() {
			do {
				audioPlayer = try AVAudioPlayer(contentsOf: silentURL)
				audioPlayer?.numberOfLoops = -1 // Lặp vô hạn
				audioPlayer?.volume = 0.01 // Gần như im lặng
				audioPlayer?.play()
			} catch {
				print("ZheeBackgroundKeeper: play lỗi: \(error)")
				return
			}
		}
		
		// Đăng ký background task
		backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ZheePythonServer") {
			// Hết thời gian - thử gia hạn
			UIApplication.shared.endBackgroundTask(self.backgroundTask)
			self.backgroundTask = .invalid
		}
		
		isKeepingAlive = true
		print("ZheeBackgroundKeeper: đã bật giữ nền")
	}
	
	/// Tắt giữ nền
	func stop() {
		audioPlayer?.stop()
		audioPlayer = nil
		
		if backgroundTask != .invalid {
			UIApplication.shared.endBackgroundTask(backgroundTask)
			backgroundTask = .invalid
		}
		
		try? AVAudioSession.sharedInstance().setActive(false)
		isKeepingAlive = false
		print("ZheeBackgroundKeeper: đã tắt giữ nền")
	}
	
	/// Tạo file wav im lặng
	private func createSilentAudio() -> URL? {
		let tempDir = FileManager.default.temporaryDirectory
		let url = tempDir.appendingPathComponent("zhee_silent.wav")
		
		// Nếu đã có thì dùng lại
		if FileManager.default.fileExists(atPath: url.path) {
			return url
		}
		
		// Tạo WAV 1 giây im lặng (44100Hz, 16-bit, mono)
		let sampleRate: Int32 = 44100
		let duration = 1
		let numSamples = Int(sampleRate) * duration
		let dataSize = numSamples * 2 // 16-bit = 2 bytes
		
		var wav = Data()
		// Header WAV
		wav.append("RIFF".data(using: .ascii)!)
		wav.append(withLittleEndian(UInt32(36 + dataSize)))
		wav.append("WAVE".data(using: .ascii)!)
		wav.append("fmt ".data(using: .ascii)!)
		wav.append(withLittleEndian(UInt32(16)))
		wav.append(withLittleEndian(UInt16(1))) // PCM
		wav.append(withLittleEndian(UInt16(1))) // mono
		wav.append(withLittleEndian(UInt32(sampleRate)))
		wav.append(withLittleEndian(UInt32(Int(sampleRate) * 2)))
		wav.append(withLittleEndian(UInt16(2)))
		wav.append(withLittleEndian(UInt16(16)))
		wav.append("data".data(using: .ascii)!)
		wav.append(withLittleEndian(UInt32(dataSize)))
		// Dữ liệu im lặng
		wav.append(Data(count: dataSize))
		
		do {
			try wav.write(to: url)
			return url
		} catch {
			print("ZheeBackgroundKeeper: tạo file lỗi: \(error)")
			return nil
		}
	}
	
	private func withLittleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
		var v = value.littleEndian
		return Data(bytes: &v, count: MemoryLayout<T>.size)
	}
}
