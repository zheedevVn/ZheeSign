//
//  ZheeProfileView.swift
//  ZheeSign
//
//  Mục profile hiện thông tin tài khoản trong Cài đặt.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeProfileView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var appear = false
	
	var body: some View {
		Section {
			HStack(spacing: 14) {
				// Avatar
				ZStack {
					if let avatarURL = auth.avatarURL {
						AsyncImage(url: avatarURL) { image in
							image.resizable()
						} placeholder: {
							ProgressView()
						}
						.frame(width: 56, height: 56)
						.clipShape(Circle())
					} else {
						ZStack {
							Circle()
								.fill(
									LinearGradient(
										colors: [.cyan, .purple, .pink],
										startPoint: .topLeading,
										endPoint: .bottomTrailing
									)
								)
								.frame(width: 56, height: 56)
							Text(String(auth.displayName.prefix(1)).uppercased())
								.font(.title2)
								.bold()
								.foregroundColor(.white)
						}
					}
				}
				.scaleEffect(appear ? 1 : 0.5)
				.opacity(appear ? 1 : 0)
				
				// Thông tin
				VStack(alignment: .leading, spacing: 4) {
					Text(auth.displayName)
						.font(.headline)
					if let email = auth.userInfo?["email"] as? String {
						Text(email)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					HStack(spacing: 4) {
						Image(systemName: "checkmark.seal.fill")
							.font(.caption)
							.foregroundStyle(.green)
						Text("Đã đăng nhập")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.opacity(appear ? 1 : 0)
				.offset(x: appear ? 0 : 20)
				
				Spacer()
			}
			.padding(.vertical, 8)
		}
		.onAppear {
			withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
				appear = true
			}
		}
	}
}
