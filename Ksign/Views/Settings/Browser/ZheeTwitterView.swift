//
//  ZheeTwitterView.swift
//  ZheeSign
//
//  Tool Twitter/X: lấy thông tin tài khoản, tải ảnh/video qua api-zhee.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import Photos
import UIKit

// Toast thông báo nổi — kiểu dáng hợp với app
struct ToastView: View {
	let message: String
	let isError: Bool
	
	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
				.font(.title2)
				.foregroundColor(.white)
			
			Text(message)
				.font(.subheadline)
				.fontWeight(.medium)
				.foregroundColor(.white)
				.multilineTextAlignment(.leading)
			
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(isError ? Color.red.gradient : Color.green.gradient)
				.shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
		)
	}
}

struct ZheeTwitterView: View {
	@State private var input = ""
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var accountInfo: TwitterAccount?
	@State private var mediaItems: [TwitterMedia] = []
	@State private var downloadingIDs: Set<UUID> = []
	@State private var successMessage: String?
	@ObservedObject var auth = ZheeAuthManager.shared
	
	var body: some View {
		ZStack(alignment: .top) {
			List {
			Section {
				HStack {
					Image("XLogo")
						.resizable()
						.scaledToFit()
						.frame(width: 24, height: 24)
					TextField("Link tweet hoặc username", text: $input)
						.autocapitalization(.none)
						.autocorrectionDisabled()
					if UIPasteboard.general.hasStrings {
						Button {
							if let s = UIPasteboard.general.string {
								input = s.trimmingCharacters(in: .whitespacesAndNewlines)
							}
						} label: {
							Image(systemName: "doc.on.clipboard")
								.foregroundColor(.accentColor)
						}
					}
				}
				
				HStack(spacing: 12) {
					Button("Thông tin") { fetchAccountInfo() }
						.buttonStyle(.borderedProminent)
						.disabled(isLoading || input.isEmpty)
					
					Button("Tải ảnh/video") { fetchMedia() }
						.buttonStyle(.bordered)
						.disabled(isLoading || input.isEmpty)
				}
			} header: {
				Label {
					Text("Twitter / X Downloader")
				} icon: {
					Image("XLogo")
						.resizable()
						.scaledToFit()
						.frame(width: 20, height: 20)
				}
			}
			
			if isLoading {
				Section {
					HStack {
						Spacer()
						ProgressView()
						Spacer()
					}
				}
			}
			
			if let account = accountInfo {
				Section("Thông tin tài khoản") {
					HStack(spacing: 12) {
						AsyncImage(url: URL(string: account.avatarURL)) { image in
							image.resizable()
						} placeholder: {
							Circle().fill(Color.gray.opacity(0.3))
						}
						.frame(width: 50, height: 50)
						.clipShape(Circle())
						
						VStack(alignment: .leading, spacing: 4) {
							Text(account.displayName)
								.font(.headline)
							Text("@\(account.username)")
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
					}
					
					if let bio = account.bio {
						Text(bio)
							.font(.body)
					}
					
					HStack(spacing: 20) {
						StatView(value: account.followers, label: "Followers")
						StatView(value: account.following, label: "Following")
						StatView(value: account.tweets, label: "Tweets")
					}
				}
			}
			
			if !mediaItems.isEmpty {
				Section("Ảnh / Video (\(mediaItems.count))") {
					ForEach(mediaItems) { item in
						HStack(spacing: 12) {
							AsyncImage(url: URL(string: item.thumbnailURL)) { image in
								image.resizable().scaledToFill()
							} placeholder: {
								Rectangle().fill(Color.gray.opacity(0.3))
							}
							.frame(width: 90, height: 90)
							.cornerRadius(12)
							
							VStack(alignment: .leading, spacing: 4) {
								Text(item.type == "video" ? "Video" : "Ảnh")
									.font(.headline)
								if downloadingIDs.contains(item.id) {
									ProgressView()
										.progressViewStyle(.linear)
								}
							}
							
							Spacer()
							
							Button {
								downloadMedia(item)
							} label: {
								Image(systemName: "arrow.down.circle.fill")
									.font(.title2)
							}
						}
					}
				}
			}
		}
		.navigationTitle("Twitter / X")
		.navigationBarTitleDisplayMode(.inline)
		.overlay(alignment: .top) {
			// Toast thông báo nổi có hiệu ứng
			VStack(spacing: 8) {
				if let error = errorMessage {
					ToastView(message: error, isError: true)
						.transition(.move(edge: .top).combined(with: .opacity))
				}
				if let success = successMessage {
					ToastView(message: success, isError: false)
						.transition(.move(edge: .top).combined(with: .opacity))
				}
			}
			.padding(.top, 8)
			.padding(.horizontal, 16)
			.animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
			.animation(.spring(response: 0.4, dampingFraction: 0.8), value: successMessage)
		}
		} // đóng ZStack
	}
	
	private func fetchAccountInfo() {
		// Dùng OAuth token - server tự verify
		guard let token = auth.accessToken, !token.isEmpty else {
			errorMessage = "Bạn chưa đăng nhập"
			return
		}
		
		let query = input.trimmingCharacters(in: .whitespaces)
		// Nếu là link tweet thì báo không phải profile
		if query.contains("twitter.com") || query.contains("x.com") {
			errorMessage = "Đây là link tweet, không phải profile — dùng nút \"Tải ảnh/video\" để tải"
			accountInfo = nil
			return
		}
		
		isLoading = true
		errorMessage = nil
		accountInfo = nil
		
		let urlString = "https://api-zhee.vercel.app/twitter?action=info&username=\(query)"
		guard let url = URL(string: urlString) else {
			isLoading = false
			errorMessage = "Link không hợp lệ"
			return
		}
		
		var req = URLRequest(url: url)
		req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		
		URLSession.shared.dataTask(with: req) { data, _, _ in
			DispatchQueue.main.async {
				isLoading = false
				guard let data = data,
					  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
					errorMessage = "Không đọc được dữ liệu"
					return
				}
				
				if let msg = json["thong_bao"] as? String {
					let status = json["trang_thai"] as? String
					if status == "that_bai" {
						// Kiểm tra hết hạn
						if msg.lowercased().contains("hết hạn") || msg.lowercased().contains("expired") {
							errorMessage = "Key đã hết hạn — lên web gia hạn thêm"
						} else {
							errorMessage = msg
						}
						return
					}
				}
				
				// Parse theo format api-zhee trả về (field tiếng Việt)
				let info = (json["thong_tin_ca_nhan"] as? [String: Any]) ?? json
				let stats = (info["thong_ke"] as? [String: Any]) ?? [:]
				var username = (info["tai_khoan"] as? String) ?? (json["username"] as? String) ?? query
				if username.hasPrefix("@") { username = String(username.dropFirst()) }
				let name = (info["ho_ten"] as? String) ?? (json["name"] as? String) ?? username
				let avatar = (info["anh_dai_dien"] as? String) ?? (json["avatar"] as? String) ?? ""
				let bio = (info["tieu_su"] as? String) ?? (json["bio"] as? String)
				let followers = (stats["nguoi_theo_doi"] as? Int) ?? (json["followers"] as? Int) ?? 0
				let following = (stats["dang_theo_doi"] as? Int) ?? (json["following"] as? Int) ?? 0
				let tweets = (stats["tong_so_tweet"] as? Int) ?? (json["tweets"] as? Int) ?? 0
				
				accountInfo = TwitterAccount(
					username: username,
					displayName: name,
					avatarURL: avatar,
					bio: bio,
					followers: followers,
					following: following,
					tweets: tweets
				)
			}
		}.resume()
	}
	
	private func fetchMedia() {
		guard let token = auth.accessToken, !token.isEmpty else {
			errorMessage = "Bạn chưa đăng nhập"
			return
		}
		isLoading = true
		errorMessage = nil
		mediaItems = []
		
		let query = input.trimmingCharacters(in: .whitespaces)
		let urlString = "https://api-zhee.vercel.app/twitter?action=media&url=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
		
		guard let url = URL(string: urlString) else {
			isLoading = false
			errorMessage = "Link không hợp lệ"
			return
		}
		
		var req = URLRequest(url: url)
		req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		
		URLSession.shared.dataTask(with: req) { data, _, _ in
			DispatchQueue.main.async {
				isLoading = false
				guard let data = data,
					  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
					errorMessage = "Không đọc được dữ liệu"
					return
				}
				
				if let msg = json["thong_bao"] as? String, json["trang_thai"] as? String == "that_bai" {
					if msg.lowercased().contains("hết hạn") || msg.lowercased().contains("expired") {
						errorMessage = "Key đã hết hạn — lên web gia hạn thêm"
					} else {
						errorMessage = msg
					}
					return
				}
				
				// Parse media list (field tiếng Việt)
				var items: [TwitterMedia] = []
				if let mediaDict = json["media"] as? [String: Any] {
					// Ảnh
					if let photos = mediaDict["danh_sach_anh"] as? [[String: Any]] {
						for p in photos {
							if let url = (p["file_anh_truc_tiep"] as? String) ?? (p["url"] as? String) {
								items.append(TwitterMedia(type: "image", url: url, thumbnailURL: url))
							} else if let url = p["link"] as? String {
								items.append(TwitterMedia(type: "image", url: url, thumbnailURL: url))
							}
						}
					} else if let photos = mediaDict["danh_sach_anh"] as? [String] {
						for url in photos {
							items.append(TwitterMedia(type: "image", url: url, thumbnailURL: url))
						}
					}
					// Video
					if let videos = mediaDict["danh_sach_video_mp4"] as? [[String: Any]] {
						for v in videos {
							if let url = (v["file_mp4_truc_tiep"] as? String) ?? (v["url"] as? String) {
								let thumb = (v["anh_thumbnail"] as? String) ?? (v["thumbnail"] as? String) ?? url
								items.append(TwitterMedia(type: "video", url: url, thumbnailURL: thumb))
							}
						}
					}
				} else if let mediaArray = json["media"] as? [[String: Any]] {
					// Fallback format cũ
					items = mediaArray.compactMap { m in
						guard let url = m["url"] as? String else { return nil }
						let type = (m["type"] as? String) ?? "image"
						let thumb = (m["thumbnail"] as? String) ?? url
						return TwitterMedia(type: type, url: url, thumbnailURL: thumb)
					}
				}
				mediaItems = items
				
				if mediaItems.isEmpty {
					errorMessage = "Không tìm thấy ảnh/video"
				}
			}
		}.resume()
	}
	
	private func downloadMedia(_ item: TwitterMedia) {
		guard let url = URL(string: item.url) else {
			errorMessage = "Link không hợp lệ"
			return
		}
		
		downloadingIDs.insert(item.id)
		errorMessage = nil
		
		URLSession.shared.downloadTask(with: url) { tempURL, _, err in
			DispatchQueue.main.async {
				downloadingIDs.remove(item.id)
			}
			if let err = err {
				DispatchQueue.main.async {
					errorMessage = "Tải thất bại: \(err.localizedDescription)"
				}
				return
			}
			guard let tempURL = tempURL else {
				DispatchQueue.main.async {
					errorMessage = "Tải thất bại"
				}
				return
			}
			
			// Xin quyền và lưu vào Photos (iOS 14+)
			if #available(iOS 14, *) {
				PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
					guard status == .authorized || status == .limited else {
						DispatchQueue.main.async {
							errorMessage = "Cần cấp quyền Photos để lưu"
						}
						return
					}
					saveToPhotos(tempURL: tempURL, item: item)
				}
			} else {
				PHPhotoLibrary.requestAuthorization { status in
					guard status == .authorized else {
						DispatchQueue.main.async {
							errorMessage = "Cần cấp quyền Photos để lưu"
						}
						return
					}
					saveToPhotos(tempURL: tempURL, item: item)
				}
			}
		}.resume()
	}
	
	private func saveToPhotos(tempURL: URL, item: TwitterMedia) {
		// Copy sang file có đuôi đúng (tránh lỗi 3302)
		let ext = item.type == "video" ? "mp4" : "jpg"
		let destURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension(ext)
		do {
			if FileManager.default.fileExists(atPath: destURL.path) {
				try FileManager.default.removeItem(at: destURL)
			}
			try FileManager.default.copyItem(at: tempURL, to: destURL)
		} catch {
			DispatchQueue.main.async {
				errorMessage = "Lưu thất bại: \(error.localizedDescription)"
			}
			return
		}
		
		PHPhotoLibrary.shared().performChanges {
			if item.type == "video" {
				PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destURL)
			} else {
				PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: destURL)
			}
		} completionHandler: { success, err in
			// Xóa file tạm
			try? FileManager.default.removeItem(at: destURL)
			try? FileManager.default.removeItem(at: tempURL)
			DispatchQueue.main.async {
				if success {
					errorMessage = nil
					successMessage = item.type == "video" ? "Đã lưu video vào thư viện ảnh" : "Đã lưu ảnh vào thư viện ảnh"
					// Tự ẩn thông báo sau 3 giây
					DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
						successMessage = nil
					}
				} else {
					errorMessage = "Lưu thất bại: \(err?.localizedDescription ?? "")"
				}
			}
		}
	}
}

struct TwitterAccount: Identifiable {
	let id = UUID()
	let username: String
	let displayName: String
	let avatarURL: String
	let bio: String?
	let followers: Int
	let following: Int
	let tweets: Int
}

struct TwitterMedia: Identifiable {
	let id = UUID()
	let type: String // "image" hoặc "video"
	let url: String
	let thumbnailURL: String
}

struct StatView: View {
	let value: Int
	let label: String
	
	var body: some View {
		VStack {
			Text("\(value)")
				.font(.headline)
			Text(label)
				.font(.caption)
				.foregroundColor(.secondary)
		}
	}
}
