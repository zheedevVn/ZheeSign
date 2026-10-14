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
					Image(systemName: "x.circle")
						.font(.title2)
						.foregroundColor(.primary)
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
				Label("Twitter / X Downloader", systemImage: "x.circle")
			} footer: {
				Text("Dùng api-zhee.vercel.app — cần đăng nhập Zhee.")
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
		// TODO: Gọi api-zhee /twitter endpoint
		errorMessage = "Đang phát triển — cần xác thực API"
	}
	
	private func fetchMedia() {
		// TODO: Gọi api-zhee /twitter endpoint
		errorMessage = "Đang phát triển — cần xác thực API"
	}
	
	private func downloadMedia(_ item: TwitterMedia) {
		// TODO: Tải về Photos
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
