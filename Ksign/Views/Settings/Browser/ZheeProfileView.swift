//
//  ZheeProfileView.swift
//  ZheeSign
//
//  Mục profile đẹp trong Cài đặt.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import PhotosUI

struct ZheeProfileView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var appear = false
	@State private var showDetail = false
	@State private var customAvatar: UIImage?
	
	var body: some View {
		Section {
			Button {
				showDetail = true
			} label: {
				HStack(spacing: 16) {
					// Avatar (không viền)
					ZStack {
						if let customAvatar = customAvatar {
							Image(uiImage: customAvatar)
								.resizable()
								.scaledToFill()
								.frame(width: 64, height: 64)
								.clipShape(Circle())
						} else if let avatarURL = auth.avatarURL {
							AsyncImage(url: avatarURL) { image in
								image.resizable()
							} placeholder: {
								ProgressView().tint(.white)
							}
							.frame(width: 64, height: 64)
							.clipShape(Circle())
						} else {
							Circle()
								.fill(Color.accentColor.gradient)
								.frame(width: 64, height: 64)
								.overlay(
									Text(String(auth.displayName.prefix(1)).uppercased())
										.font(.system(size: 26, weight: .bold))
										.foregroundColor(.white)
								)
						}
					}
					.scaleEffect(appear ? 1 : 0.4)
					.opacity(appear ? 1 : 0)
					
					// Thông tin
					VStack(alignment: .leading, spacing: 5) {
						Text(auth.displayName)
							.font(.headline)
							.foregroundStyle(
								LinearGradient(colors: [.primary, .primary.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
							)
						
						if let email = auth.userInfo?["email"] as? String {
							Text(email)
								.font(.subheadline)
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
						
						HStack(spacing: 5) {
							Image(systemName: "checkmark.seal.fill")
								.font(.caption)
								.foregroundStyle(Color.accentColor)
							Text("Tài khoản Zhee")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
					.opacity(appear ? 1 : 0)
					.offset(x: appear ? 0 : 25)
					
					Spacer()
					
					Image(systemName: "chevron.right")
						.font(.caption)
						.foregroundStyle(.tertiary)
						.opacity(appear ? 1 : 0)
				}
				.padding(.vertical, 12)
				.listRowInsets(EdgeInsets())
				.listRowBackground(Color.clear)
				.padding(.vertical, 4)
			}
			.buttonStyle(.plain)
		}
		.sheet(isPresented: $showDetail) {
			ZheeProfileDetailView()
				.presentationDetents([.medium, .large])
				.presentationDragIndicator(.visible)
		}
		.onReceive(NotificationCenter.default.publisher(for: Notification.Name("zhee.avatarChanged"))) { _ in
			loadAvatar()
		}
		.onAppear {
			loadAvatar()
			withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
				appear = true
			}

		}
	}
}

extension ZheeProfileView {
	private func loadAvatar() {
		if let data = UserDefaults.standard.data(forKey: "zhee.customAvatar"),
		   let image = UIImage(data: data) {
			customAvatar = image
		} else {
			customAvatar = nil
		}
	}
}

struct ZheeProfileDetailView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@Environment(\.dismiss) var dismiss
	@State private var appear = false
	@State private var selectedPhoto: PhotosPickerItem?
	@State private var customAvatar: UIImage?
	@State private var showPhotoPicker = false
	
	var body: some View {
		NavigationView {
			ScrollView {
				VStack(spacing: 24) {
					// Avatar lon - bam de doi
					Button {
						showPhotoPicker = true
					} label: {
						ZStack {
							if let customAvatar = customAvatar {
								Image(uiImage: customAvatar)
									.resizable()
									.scaledToFill()
									.frame(width: 110, height: 110)
									.clipShape(Circle())
									.shadow(color: .accentColor.opacity(0.4), radius: 20)
							} else if let avatarURL = auth.avatarURL {
								AsyncImage(url: avatarURL) { image in
									image.resizable()
								} placeholder: {
									ProgressView().tint(.white)
								}
								.frame(width: 110, height: 110)
								.clipShape(Circle())
								.shadow(color: .accentColor.opacity(0.4), radius: 20)
							} else {
								Circle()
									.fill(Color.accentColor.gradient)
									.frame(width: 110, height: 110)
									.shadow(color: .accentColor.opacity(0.4), radius: 20)
									.overlay(
										Text(String(auth.displayName.prefix(1)).uppercased())
											.font(.system(size: 44, weight: .bold))
											.foregroundColor(.white)
									)
							}
							
							// Icon camera
							Circle()
								.fill(Color.black.opacity(0.6))
								.frame(width: 32, height: 32)
								.overlay(
									Image(systemName: "camera.fill")
										.font(.caption)
										.foregroundColor(.white)
								)
								.offset(x: 38, y: 38)
						}
					}
					.buttonStyle(.plain)
					.scaleEffect(appear ? 1 : 0.5)
					.opacity(appear ? 1 : 0)
					.photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
					.onChange(of: selectedPhoto) { newItem in
						Task {
							if let data = try? await newItem?.loadTransferable(type: Data.self),
							   let image = UIImage(data: data) {
								customAvatar = image
								// Luu avatar
								if let jpegData = image.jpegData(compressionQuality: 0.8) {
									UserDefaults.standard.set(jpegData, forKey: "zhee.customAvatar")
								}
								// Bao cho card ngoai cap nhat ngay, khong can mo lai app
								NotificationCenter.default.post(name: Notification.Name("zhee.avatarChanged"), object: nil)
							}
						}
					}
					.onAppear {
						// Tai avatar da luu
						if let data = UserDefaults.standard.data(forKey: "zhee.customAvatar"),
						   let image = UIImage(data: data) {
							customAvatar = image
						}
					}
					
					// Ten
					VStack(spacing: 6) {
						Text(auth.displayName)
							.font(.title2.bold())
						HStack(spacing: 5) {
							Image(systemName: "checkmark.seal.fill")
								.foregroundStyle(Color.accentColor)
							Text("Tài khoản Zhee đã xác thực")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
					
					// Thong tin chi tiet
					VStack(spacing: 0) {
						if let name = auth.userInfo?["name"] as? String {
							detailRow(icon: "person.text.rectangle.fill", title: "Tên hiển thị", value: name)
						}
						if let username = auth.userInfo?["preferred_username"] as? String ?? auth.userInfo?["username"] as? String {
							detailRow(icon: "at", title: "Tên đăng nhập", value: username)
						}
						if let email = auth.userInfo?["email"] as? String {
							detailRow(icon: "envelope.fill", title: "Email", value: email)
						}
						if let sub = auth.userInfo?["sub"] as? String {
							detailRow(icon: "person.fill", title: "ID người dùng", value: sub)
						}
						// Hiển thị hạn secret key
						if let expiryText = secretExpiryText {
							detailRow(icon: "key.fill", title: "Secret key", value: expiryText)
						}
						detailRow(icon: "calendar", title: "Phiên đăng nhập", value: "30 ngày")
						detailRow(icon: "clock.fill", title: "Đăng nhập lúc", value: loginTimeString)
						detailRow(icon: "shield.fill", title: "Bảo mật", value: "OAuth 2.0")
						detailRow(icon: "app.badge.fill", title: "Phiên bản app", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
					}
					.background(Color(.secondarySystemBackground))
					.clipShape(RoundedRectangle(cornerRadius: 16))
					.padding(.horizontal)
					
					// Nut dang xuat
					Button(role: .destructive) {
						auth.logout()
						dismiss()
					} label: {
						HStack {
							Image(systemName: "rectangle.portrait.and.arrow.right")
							Text("Đăng xuất")
						}
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.red.opacity(0.1))
						.clipShape(RoundedRectangle(cornerRadius: 14))
					}
					.padding(.horizontal)
				}
				.padding(.vertical, 24)
			}
			.navigationTitle("Hồ sơ")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Xong") { dismiss() }
				}
			}
		}
		.onAppear {
			withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
				appear = true
			}
		}
	}
	
	private var loginTimeString: String {
		let loginDate = UserDefaults.standard.object(forKey: "zhee.loginDate") as? Date ?? Date()
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm dd/MM/yyyy"
		formatter.locale = Locale(identifier: "vi_VN")
		return formatter.string(from: loginDate)
	}
	
	/// Thời gian còn lại của secret key (10 ngày từ lúc lưu)
	private var secretExpiryText: String? {
		guard UserDefaults.standard.string(forKey: "zhee_api_secret") != nil else { return nil }
		// Ưu tiên expiry từ userinfo nếu API trả về
		if let expiry = auth.userInfo?["secret_expires_at"] as? Double {
			let remaining = Int(expiry - Date().timeIntervalSince1970)
			if remaining <= 0 { return "Đã hết hạn" }
			let days = remaining / 86400
			let hours = (remaining % 86400) / 3600
			if days > 0 { return "Còn \(days) ngày" }
			return "Còn \(hours) giờ"
		}
		// Fallback: tính từ lúc lưu key (giả định 10 ngày)
		if let savedDate = UserDefaults.standard.object(forKey: "zhee_api_secret_date") as? Date {
			let expiry = savedDate.addingTimeInterval(10 * 24 * 3600)
			let remaining = Int(expiry.timeIntervalSinceNow)
			if remaining <= 0 { return "Đã hết hạn" }
			let days = remaining / 86400
			if days > 0 { return "Còn \(days) ngày" }
			let hours = (remaining % 3600) / 3600
			return "Còn \(hours) giờ"
		}
		return "Không rõ hạn"
	}
	
	private func detailRow(icon: String, title: String, value: String) -> some View {
		HStack {
			Image(systemName: icon)
				.foregroundStyle(.blue)
				.frame(width: 28)
			Text(title)
				.foregroundStyle(.secondary)
			Spacer()
			Text(value)
				.font(.subheadline)
				.lineLimit(1)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
	}
}
