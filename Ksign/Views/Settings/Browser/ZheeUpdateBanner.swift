//
//  ZheeUpdateBanner.swift
//  ZheeSign
//
//  Banner thông báo có bản mới khi mở app.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeUpdateBanner: View {
	@ObservedObject var updater = ZheeUpdateManager.shared
	@State private var showBanner = false
	
	var body: some View {
		VStack(spacing: 0) {
			if showBanner, let version = updater.latestVersion {
				HStack(spacing: 12) {
					Image(systemName: "arrow.down.circle.fill")
						.font(.title2)
						.foregroundStyle(.white)
					
					VStack(alignment: .leading, spacing: 2) {
						Text("Có bản mới v\(version)")
							.font(.subheadline.bold())
							.foregroundColor(.white)
						Text("Chạm để cập nhật ngay")
							.font(.caption)
							.foregroundColor(.white.opacity(0.85))
					}
					
					Spacer()
					
					Image(systemName: "chevron.right")
						.foregroundColor(.white.opacity(0.7))
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
				.background(
					LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
				)
				.onTapGesture {
					updater.installUpdate()
				}
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(.spring(response: 0.5), value: showBanner)
		.onAppear {
			// Check update khi mở app
			updater.checkForUpdates()
			// Hiện banner sau 1.5s nếu có update
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
				if updater.updateAvailable {
					withAnimation {
						showBanner = true
					}
				}
			}
		}
		.onChange(of: updater.updateAvailable) { available in
			if available {
				withAnimation {
					showBanner = true
				}
			}
		}
	}
}
