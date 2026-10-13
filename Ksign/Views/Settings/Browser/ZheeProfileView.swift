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
	@State private var glowShift = false
	@State private var showDetail = false
	@State private var customAvatar: UIImage?
	
	var body: some View {
		Section {
			Button {
				showDetail = true
			} label: {
				ZStack {
				// Nền gradient card
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(
						LinearGradient(
							colors: glowShift
								? [Color.purple.opacity(0.25), Color.cyan.opacity(0.15)]
								: [Color.cyan.opacity(0.15), Color.purple.opacity(0.25)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.stroke(
								LinearGradient(colors: [.cyan.opacity(0.5), .purple.opacity(0.5), .pink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
								lineWidth: 1
							)
					)
				
				HStack(spacing: 16) {
					// Avatar với viền gradient
					ZStack {
						Circle()
							.fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
							.frame(width: 64, height: 64)
						
						if let customAvatar = customAvatar {
							Image(uiImage: customAvatar)
								.resizable()
								.scaledToFill()
								.frame(width: 58, height: 58)
								.clipShape(Circle())
						} else if let avatarURL = auth.avatarURL {
							AsyncImage(url: avatarURL) { image in
								image.resizable()
							} placeholder: {
								ProgressView().tint(.white)
							}
							.frame(width: 58, height: 58)
							.clipShape(Circle())
						} else {
							Text(String(auth.displayName.prefix(1)).uppercased())
								.font(.system(size: 26, weight: .bold))
								.foregroundColor(.white)
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
								.foregroundStyle(
									LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
								)
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
				.padding(16)
			}
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
		.onAppear {
			if let data = UserDefaults.standard.data(forKey: "zhee.customAvatar"),
			   let image = UIImage(data: data) {
				customAvatar = image
			}
			withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
				appear = true
			}
			withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
				glowShift = true
			}
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
							Circle()
								.fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
								.frame(width: 110, height: 110)
								.shadow(color: .purple.opacity(0.4), radius: 20)
							
							if let customAvatar = customAvatar {
								Image(uiImage: customAvatar)
									.resizable()
									.scaledToFill()
									.frame(width: 100, height: 100)
									.clipShape(Circle())
							} else if let avatarURL = auth.avatarURL {
								AsyncImage(url: avatarURL) { image in
									image.resizable()
								} placeholder: {
									ProgressView().tint(.white)
								}
								.frame(width: 100, height: 100)
								.clipShape(Circle())
							} else {
								Text(String(auth.displayName.prefix(1)).uppercased())
									.font(.system(size: 44, weight: .bold))
									.foregroundColor(.white)
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
								.foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
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
