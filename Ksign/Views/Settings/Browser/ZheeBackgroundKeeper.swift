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
	@Published var lastError: String?
	
	private var audioPlayer: AVAudioPlayer?
	private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
	
	private init() {}
	
	/// Bật giữ app chạy nền. Trả về true nếu thành công.
	@discardableResult
	func start() -> Bool {
		guard !isKeepingAlive else { return true }
		lastError = nil
		
		// 1. Cấu hình audio session
		do {
			let session = AVAudioSession.sharedInstance()
			try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
			try session.setActive(true, options: [])
		} catch {
			lastError = "Không bật được audio: \(error.localizedDescription)"
			return false
		}
		
		// 2. Tạo và phát audio im lặng lặp vô hạn
		guard let silentURL = createSilentAudio() else {
			lastError = "Không tạo được file audio"
			try? AVAudioSession.sharedInstance().setActive(false)
			return false
		}
		
		do {
			audioPlayer = try AVAudioPlayer(contentsOf: silentURL)
			guard let player = audioPlayer else {
				lastError = "Không khởi tạo được player"
				return false
			}
			player.numberOfLoops = -1
			player.volume = 0.0 // Hoàn toàn im lặng
			if !player.play() {
				lastError = "Không phát được audio"
				return false
			}
			// Xác nhận đang phát
			if !player.isPlaying {
				lastError = "Audio không chạy"
				return false
			}
		} catch {
			lastError = "Lỗi player: \(error.localizedDescription)"
			return false
		}
		
		// 3. Đăng ký background task để có thêm thời gian
		backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ZheePythonServer") { [weak self] in
			guard let self = self else { return }
			// Xin thêm thời gian
			if self.backgroundTask != .invalid {
				UIApplication.shared.endBackgroundTask(self.backgroundTask)
			}
			self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ZheePythonServer-renew") {}
		}
		
		isKeepingAlive = true
		return true
	}
	
	/// Tắt giữ nền
	func stop() {
		audioPlayer?.stop()
		audioPlayer = nil
		
		if backgroundTask != .invalid {
			UIApplication.shared.endBackgroundTask(backgroundTask)
			backgroundTask = .invalid
		}
		
		try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
		isKeepingAlive = false
		lastError = nil
	}
	
	/// Tạo file WAV im lặng 2 giây (44.1kHz, 16-bit mono)
	private func createSilentAudio() -> URL? {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("zhee_silent.wav")
		
		// Xóa file cũ nếu có để tạo mới chắc chắn
		try? FileManager.default.removeItem(at: url)
		
		let sampleRate: UInt32 = 44100
		let channels: UInt16 = 1
		let bitsPerSample: UInt16 = 16
		let durationSeconds = 2
		let numSamples = Int(sampleRate) * durationSeconds
		let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
		let blockAlign = channels * bitsPerSample / 8
		let dataSize = numSamples * Int(blockAlign)
		
		var data = Data()
		data.append(contentsOf: "RIFF".utf8)
		data.appendUInt32(UInt32(36 + dataSize))
		data.append(contentsOf: "WAVE".utf8)
		data.append(contentsOf: "fmt ".utf8)
		data.appendUInt32(16)
		data.appendUInt16(1) // PCM
		data.appendUInt16(channels)
		data.appendUInt32(sampleRate)
		data.appendUInt32(byteRate)
		data.appendUInt16(blockAlign)
		data.appendUInt16(bitsPerSample)
		data.append(contentsOf: "data".utf8)
		data.appendUInt32(UInt32(dataSize))
		data.append(Data(count: dataSize)) // Im lặng
		
		do {
			try data.write(to: url, options: .atomic)
			return url
		} catch {
			lastError = "Ghi file audio lỗi: \(error.localizedDescription)"
			return nil
		}
	}
}

private extension Data {
	mutating func appendUInt32(_ value: UInt32) {
		var v = value.littleEndian
		append(Data(bytes: &v, count: 4))
	}
	mutating func appendUInt16(_ value: UInt16) {
		var v = value.littleEndian
		append(Data(bytes: &v, count: 2))
	}
}
