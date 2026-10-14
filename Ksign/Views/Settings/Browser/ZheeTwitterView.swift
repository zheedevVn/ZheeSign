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

struct ZheeTwitterView: View {
	@State private var input = ""
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var accountInfo: TwitterAccount?
	@State private var mediaItems: [TwitterMedia] = []
	@State private var downloadingIDs: Set<UUID> = []
	@ObservedObject var auth = ZheeAuthManager.shared
	
	var body: some View {
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
			
			if let error = errorMessage {
				Section {
					Text(error)
						.foregroundColor(.red)
						.font(.caption)
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
	}
	
	private func fetchAccountInfo() {
		// Dùng OAuth token - server tự verify
		guard let token = auth.accessToken, !token.isEmpty else {
			errorMessage = "Bạn chưa đăng nhập"
			return
		}
		isLoading = true
		errorMessage = nil
		accountInfo = nil
		
		let query = input.trimmingCharacters(in: .whitespaces)
		var urlString = "https://api-zhee.vercel.app/twitter?action=info&username=\(query)"
		if query.contains("twitter.com") || query.contains("x.com") {
			urlString = "https://api-zhee.vercel.app/twitter?action=info&url=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
		}
		
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
		PHPhotoLibrary.shared().performChanges {
			if item.type == "video" {
				PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
			} else {
				PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
			}
		} completionHandler: { success, err in
			DispatchQueue.main.async {
				if success {
					errorMessage = nil
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
