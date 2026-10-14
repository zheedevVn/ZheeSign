//
//  ZheeTwitterView.swift
//  ZheeSign
//
//  Tool Twitter/X: lấy thông tin tài khoản, tải ảnh/video qua api-zhee.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import Photos

struct ZheeTwitterView: View {
	@State private var input = ""
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var accountInfo: TwitterAccount?
	@State private var mediaItems: [TwitterMedia] = []
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
						HStack {
							AsyncImage(url: URL(string: item.thumbnailURL)) { image in
								image.resizable().scaledToFill()
							} placeholder: {
								Rectangle().fill(Color.gray.opacity(0.3))
							}
							.frame(width: 60, height: 60)
							.cornerRadius(8)
							
							VStack(alignment: .leading) {
								Text(item.type == "video" ? "Video" : "Ảnh")
									.font(.headline)
								Text(item.url)
									.font(.caption)
									.foregroundColor(.secondary)
									.lineLimit(1)
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
				
				// Parse theo format api-zhee trả về
				let username = (json["username"] as? String) ?? query
				let name = (json["name"] as? String) ?? (json["display_name"] as? String) ?? username
				let avatar = (json["avatar"] as? String) ?? (json["profile_image"] as? String) ?? ""
				let bio = (json["bio"] as? String) ?? (json["description"] as? String)
				let followers = (json["followers"] as? Int) ?? 0
				let following = (json["following"] as? Int) ?? 0
				let tweets = (json["tweets"] as? Int) ?? (json["statuses_count"] as? Int) ?? 0
				
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
				
				// Parse media list
				if let mediaArray = json["media"] as? [[String: Any]] {
					mediaItems = mediaArray.compactMap { m in
						guard let url = m["url"] as? String else { return nil }
						let type = (m["type"] as? String) ?? "image"
						let thumb = (m["thumbnail"] as? String) ?? url
						return TwitterMedia(type: type, url: url, thumbnailURL: thumb)
					}
				}
				
				if mediaItems.isEmpty {
					errorMessage = "Không tìm thấy ảnh/video"
				}
			}
		}.resume()
	}
	
	private func downloadMedia(_ item: TwitterMedia) {
		guard let url = URL(string: item.url) else { return }
		
		URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
			guard let tempURL = tempURL else { return }
			
			// Xin quyền và lưu vào Photos
			PHPhotoLibrary.requestAuthorization { status in
				guard status == .authorized else { return }
				
				PHPhotoLibrary.shared().performChanges {
					if item.type == "video" {
						PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
					} else {
						PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
					}
				} completionHandler: { success, _ in
					DispatchQueue.main.async {
						errorMessage = success ? nil : "Lưu thất bại"
					}
				}
			}
		}.resume()
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
