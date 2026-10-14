//
//  ZheeNetworkMonitor.swift
//  ZheeSign
//
//  Theo dõi trạng thái mạng — báo mất kết nối, khóa tính năng online khi offline.
//  © 2026 Hồ Đức Minh
//

import Foundation
import Network
import SwiftUI
import Combine

class ZheeNetworkMonitor: ObservableObject {
	static let shared = ZheeNetworkMonitor()
	
	@Published var isConnected = true
	@Published var connectionType = "WiFi"
	
	private let monitor = NWPathMonitor()
	private let queue = DispatchQueue(label: "zhee.network.monitor")
	
	private init() {
		monitor.pathUpdateHandler = { [weak self] path in
			DispatchQueue.main.async {
				self?.isConnected = path.status == .satisfied
				if path.usesInterfaceType(.wifi) {
					self?.connectionType = "WiFi"
				} else if path.usesInterfaceType(.cellular) {
					self?.connectionType = "Di động"
				} else if path.usesInterfaceType(.wiredEthernet) {
					self?.connectionType = "Dây"
				} else {
					self?.connectionType = "Không rõ"
				}
			}
		}
		monitor.start(queue: queue)
	}
	
	deinit {
		monitor.cancel()
	}
}

// Banner mất mạng — kiểu pill đen như Facebook, trên đầu, 3s tự ẩn
struct ZheeOfflineBanner: View {
	@ObservedObject var monitor = ZheeNetworkMonitor.shared
	@State private var showToast = false
	
	var body: some View {
		Group {
			if showToast {
				HStack(spacing: 10) {
					Image(systemName: monitor.isConnected ? "wifi" : "wifi.slash")
						.font(.body)
					Text(monitor.isConnected ? "Đã có mạng trở lại" : "Bạn đang offline.")
						.font(.subheadline)
						.fontWeight(.medium)
				}
				.foregroundColor(.white)
				.padding(.horizontal, 20)
				.padding(.vertical, 12)
				.background(
					Capsule()
						.fill(Color.black.opacity(0.85))
						.shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
				)
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.onChange(of: monitor.isConnected) { connected in
			// Hiện 3s rồi tự ẩn
			withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
				showToast = true
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
				withAnimation(.easeOut(duration: 0.3)) {
					showToast = false
				}
			}
		}
		.onAppear {
			// Hiện ngay nếu đang offline khi mở
			if !monitor.isConnected {
				showToast = true
				DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
					withAnimation(.easeOut(duration: 0.3)) {
						showToast = false
					}
				}
			}
		}
	}
}
