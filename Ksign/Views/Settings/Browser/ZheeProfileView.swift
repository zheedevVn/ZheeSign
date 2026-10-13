//
//  ZheeProfileView.swift
//  ZheeSign
//
//  Mục profile đẹp trong Cài đặt.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeProfileView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var appear = false
	@State private var glowShift = false
	
	var body: some View {
		Section {
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
						
						if let avatarURL = auth.avatarURL {
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
		.onAppear {
			withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
				appear = true
			}
			withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
				glowShift = true
			}
		}
	}
}
