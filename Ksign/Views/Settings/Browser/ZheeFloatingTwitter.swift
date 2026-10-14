//
//  ZheeFloatingTwitter.swift
//  ZheeSign
//
//  Nút nổi PiP cho Twitter — dán link là tự tải, không cần chuyển tab.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import Photos

/// Nút nổi Twitter — kéo thả được, bấm để mở mini downloader
struct ZheeFloatingTwitter: View {
	@State private var position = CGPoint(x: 320, y: 500)
	@State private var isExpanded = false
	@State private var input = ""
	@State private var isLoading = false
	@State private var statusMessage: String?
	@State private var isSuccess = false
	@State private var dragOffset = CGSize.zero
	@ObservedObject var auth = ZheeAuthManager.shared
	
	var body: some View {
		ZStack {
			if isExpanded {
				// Mini panel
				VStack(spacing: 12) {
					HStack {
						Text("𝕏")
							.font(.title3)
							.fontWeight(.bold)
						Text("Tải video X")
							.font(.headline)
						Spacer()
						Button {
							withAnimation(.spring()) { isExpanded = false }
						} label: {
							Image(systemName: "xmark.circle.fill")
								.font(.title3)
								.foregroundColor(.secondary)
						}
					}
					
					HStack {
						TextField("Dán link video X...", text: $input)
							.autocapitalization(.none)
							.autocorrectionDisabled()
							.padding(10)
							.background(Color(.systemGray6))
							.cornerRadius(10)
						
						// Nút dán
						Button {
							if let s = UIPasteboard.general.string {
								input = s.trimmingCharacters(in: .whitespacesAndNewlines)
								// Tự tải ngay sau khi dán
								fetchAndDownload()
							}
						} label: {
							Image(systemName: "doc.on.clipboard.fill")
								.font(.title3)
								.foregroundColor(.white)
								.padding(10)
								.background(Color.blue)
								.cornerRadius(10)
						}
					}
					
					Button {
						fetchAndDownload()
					} label: {
						HStack {
							if isLoading {
								ProgressView()
									.tint(.white)
							} else {
								Image(systemName: "arrow.down.circle.fill")
							}
							Text(isLoading ? "Đang tải..." : "Tải xuống")
						}
						.font(.headline)
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 12)
						.background(Color.blue.gradient)
						.cornerRadius(12)
					}
					.disabled(isLoading || input.isEmpty)
					
					if let msg = statusMessage {
						Text(msg)
							.font(.caption)
							.foregroundColor(isSuccess ? .green : .red)
							.multilineTextAlignment(.center)
					}
				}
				.padding(16)
				.frame(width: 300)
				.background(
					RoundedRectangle(cornerRadius: 20)
						.fill(.ultraThinMaterial)
						.shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
				)
				.position(x: position.x, y: position.y)
				.transition(.scale.combined(with: .opacity))
			} else {
				// Nút nổi tròn
				Button {
					// Tự lấy link từ clipboard nếu có
					if let s = UIPasteboard.general.string,
					   (s.contains("x.com") || s.contains("twitter.com")) {
						input = s.trimmingCharacters(in: .whitespacesAndNewlines)
					}
					withAnimation(.spring()) { isExpanded = true }
				} label: {
					ZStack {
						Circle()
							.fill(Color.black.gradient)
							.frame(width: 60, height: 60)
							.shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
						Text("𝕏")
							.font(.title2)
							.fontWeight(.bold)
							.foregroundColor(.white)
					}
				}
				.position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
				.gesture(
					DragGesture()
						.onChanged { value in
							dragOffset = value.translation
						}
						.onEnded { _ in
							position.x += dragOffset.width
							position.y += dragOffset.height
							dragOffset = .zero
							// Giữ trong màn hình
							position.x = min(max(position.x, 40), UIScreen.main.bounds.width - 40)
							position.y = min(max(position.y, 100), UIScreen.main.bounds.height - 150)
						}
				)
			}
		}
	}
	
	/// Lấy media và tải ngay
	private func fetchAndDownload() {
		guard let token = auth.accessToken, !token.isEmpty else {
			statusMessage = "Bạn chưa đăng nhập"
			isSuccess = false
			return
		}
		let query = input.trimmingCharacters(in: .whitespaces)
		guard !query.isEmpty else { return }
		
		isLoading = true
		statusMessage = nil
		
		let urlString = "\(ZheeSecurity.apiBaseURL)/twitter?action=media&url=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
		guard let url = URL(string: urlString) else {
			isLoading = false
			return
		}
		
		var request = URLRequest(url: url)
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		request.timeoutInterval = 15
		
		URLSession.shared.dataTask(with: request) { data, _, _ in
			DispatchQueue.main.async {
				isLoading = false
				guard let data = data,
				      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				      let mediaDict = json["media"] as? [String: Any] else {
					statusMessage = "Không lấy được media"
					isSuccess = false
					return
				}
				
				// Lấy video đầu tiên
				var mediaURL: String?
				if let videos = mediaDict["danh_sach_video_mp4"] as? [[String: Any]],
				   let first = videos.first {
					mediaURL = first["file_mp4_truc_tiep"] as? String
				} else if let photos = mediaDict["danh_sach_anh"] as? [[String: Any]],
				          let first = photos.first {
					mediaURL = first["file_anh_truc_tiep"] as? String ?? first["url"] as? String
				}
				
				guard let mediaURLString = mediaURL,
				      let mediaURLObj = URL(string: mediaURLString) else {
					statusMessage = "Không tìm thấy ảnh/video"
					isSuccess = false
					return
				}
				
				downloadAndSave(url: mediaURLObj, isVideo: mediaURLString.contains(".mp4"))
			}
		}.resume()
	}
	
	/// Tải và lưu vào Photos
	private func downloadAndSave(url: URL, isVideo: Bool) {
		statusMessage = "Đang lưu..."
		URLSession.shared.downloadTask(with: url) { tempURL, _, err in
			DispatchQueue.main.async {
				if let err = err {
					statusMessage = "Tải thất bại: \(err.localizedDescription)"
					isSuccess = false
					return
				}
				guard let tempURL = tempURL else {
					statusMessage = "Tải thất bại"
					isSuccess = false
					return
				}
				
				let ext = isVideo ? "mp4" : "jpg"
				let destURL = FileManager.default.temporaryDirectory
					.appendingPathComponent(UUID().uuidString)
					.appendingPathExtension(ext)
				do {
					if FileManager.default.fileExists(atPath: destURL.path) {
						try FileManager.default.removeItem(at: destURL)
					}
					try FileManager.default.copyItem(at: tempURL, to: destURL)
				} catch {
					statusMessage = "Lưu thất bại"
					isSuccess = false
					return
				}
				
				PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
					guard status == .authorized || status == .limited else {
						DispatchQueue.main.async {
							statusMessage = "Cần cấp quyền Photos"
							isSuccess = false
						}
						return
					}
					PHPhotoLibrary.shared().performChanges {
						if isVideo {
							PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destURL)
						} else {
							PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: destURL)
						}
					} completionHandler: { success, _ in
						try? FileManager.default.removeItem(at: destURL)
						try? FileManager.default.removeItem(at: tempURL)
						DispatchQueue.main.async {
							if success {
								statusMessage = "Đã lưu vào thư viện ✅"
								isSuccess = true
								// Tự thu nhỏ sau 2s
								DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
									withAnimation(.spring()) { isExpanded = false }
									input = ""
									statusMessage = nil
								}
							} else {
								statusMessage = "Lưu thất bại"
								isSuccess = false
							}
						}
					}
				}
			}
		}.resume()
	}
}
