//
//  ZheeUpdateView.swift
//  ZheeSign
//
//  UI kiểm tra cập nhật trong Cài đặt.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeUpdateView: View {
	@ObservedObject var updater = ZheeUpdateManager.shared
	@State private var showNotes = false
	
	var body: some View {
		Section {
			HStack {
				Label("Kiểm tra cập nhật", systemImage: "arrow.triangle.2.circlepath")
				Spacer()
				if updater.isChecking {
					ProgressView()
						.scaleEffect(0.8)
				} else {
					Text("v\(updater.currentVersion)")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.contentShape(Rectangle())
			.onTapGesture {
				updater.checkForUpdates()
			}
			
			if updater.updateAvailable {
				Button {
					showNotes = true
				} label: {
					HStack {
						Label("Có bản mới!", systemImage: "sparkles")
							.foregroundStyle(.blue)
						Spacer()
						Image(systemName: "chevron.right")
							.font(.caption)
							.foregroundStyle(.tertiary)
					}
				}
			}
		}
		.alert("Có bản cập nhật mới", isPresented: $showNotes) {
			Button("Cập nhật ngay") {
				updater.installUpdate()
			}
			Button("Để sau", role: .cancel) {
				updater.dismissUpdate()
			}
		} message: {
			Text("Bản mới sẽ được cài đè lên app hiện tại, không cần xóa. Dữ liệu đăng nhập được giữ nguyên.")
		}
		.onAppear {
			// Tự động check khi vào Cài đặt
			updater.checkForUpdates()
		}
	}
}
