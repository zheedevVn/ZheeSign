//
//  ZheePrivacySettingsView.swift
//  ZheeSign
//
//  Gom toàn bộ cài đặt bảo mật & quyền riêng tư.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheePrivacySettingsView: View {
	@ObservedObject var lock = ZheeAppLockManager.shared
	
	var body: some View {
		Form {
			Section {
				NavigationLink(destination: ZheeAppLockSettingsView()) {
					HStack {
						Image(systemName: "lock.fill")
							.foregroundColor(.white)
							.frame(width: 28, height: 28)
							.background(RoundedRectangle(cornerRadius: 7).fill(Color.accentColor))
						Text("Khóa ứng dụng")
						Spacer()
						Text(lock.isEnabled ? "Bật" : "Tắt")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
			} header: {
				Text("Bảo mật")
			} footer: {
				Text("Khóa ZheeSign bằng Face ID, Touch ID hoặc mã PIN.")
			}
		}
		.navigationTitle("Cài đặt và quyền riêng tư")
		.navigationBarTitleDisplayMode(.inline)
	}
}
