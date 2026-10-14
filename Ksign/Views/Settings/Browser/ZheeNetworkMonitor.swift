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
	@Published var showToast = false
	
	private let monitor = NWPathMonitor()
	private let queue = DispatchQueue(label: "zhee.network.monitor")
	private var toastWorkItem: DispatchWorkItem?
	
	private init() {
		monitor.pathUpdateHandler = { [weak self] path in
			DispatchQueue.main.async {
				let wasConnected = self?.isConnected ?? true
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
				// Chỉ toast khi trạng thái thay đổi thật
				if wasConnected != self?.isConnected {
					self?.showToastOnce()
				}
			}
		}
		monitor.start(queue: queue)
	}
	
	/// Hiện toast 3s rồi ẩn, hủy lịch cũ nếu có (tránh trùng)
	func showToastOnce() {
		toastWorkItem?.cancel()
		withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
			showToast = true
		}
		let work = DispatchWorkItem { [weak self] in
			withAnimation(.easeOut(duration: 0.3)) {
				self?.showToast = false
			}
		}
		toastWorkItem = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
	}
	
	deinit {
		monitor.cancel()
	}
}

// Banner mất mạng — kiểu pill đen như Facebook, trên cùng ở giữa, mọi tab
struct ZheeOfflineBanner: View {
	@ObservedObject var monitor = ZheeNetworkMonitor.shared
	
	var body: some View {
		Group {
			if monitor.showToast {
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
		.animation(.spring(response: 0.4, dampingFraction: 0.8), value: monitor.showToast)
	}
}
