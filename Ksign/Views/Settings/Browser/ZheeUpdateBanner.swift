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
				VStack(spacing: 8) {
					HStack(spacing: 12) {
						Image(systemName: "arrow.down.circle.fill")
							.font(.title2)
							.foregroundStyle(.white)
						
						VStack(alignment: .leading, spacing: 2) {
							Text("Có bản mới v\(version)")
								.font(.subheadline.bold())
								.foregroundColor(.white)
							if updater.isDownloading {
								Text("Đang tải \(Int(updater.downloadProgress * 100))%")
									.font(.caption)
									.foregroundColor(.white.opacity(0.85))
							} else if updater.downloadedFileURL != nil {
								Text("Tải xong - chạm để cài đặt")
									.font(.caption)
									.foregroundColor(.white.opacity(0.85))
							} else {
								Text("Chạm để tải bản mới")
									.font(.caption)
									.foregroundColor(.white.opacity(0.85))
							}
						}
						
						Spacer()
						
						if updater.isDownloading {
							Button("Hủy") {
								updater.cancelDownload()
							}
							.font(.caption.bold())
							.foregroundColor(.white)
							.padding(.horizontal, 12)
							.padding(.vertical, 6)
							.background(Color.white.opacity(0.25))
							.cornerRadius(8)
						} else if updater.downloadedFileURL != nil {
							Image(systemName: "square.and.arrow.up")
								.foregroundColor(.white)
						} else {
							Image(systemName: "chevron.right")
								.foregroundColor(.white.opacity(0.7))
						}
					}
					
					if updater.isDownloading {
						ProgressView(value: updater.downloadProgress)
							.tint(.white)
							.background(Color.white.opacity(0.3))
							.cornerRadius(4)
					}
					
					if let err = updater.downloadError {
						Text(err)
							.font(.caption2)
							.foregroundColor(.yellow)
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
				.background(
					LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
				)
				.onTapGesture {
					if updater.downloadedFileURL != nil {
						updater.shareDownloadedFile()
					} else if !updater.isDownloading {
						updater.downloadUpdate()
					}
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
