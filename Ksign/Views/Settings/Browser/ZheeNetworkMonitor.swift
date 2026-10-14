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

// Banner mất mạng — hiện trên đầu màn hình
struct ZheeOfflineBanner: View {
	@ObservedObject var monitor = ZheeNetworkMonitor.shared
	
	var body: some View {
		if !monitor.isConnected {
			HStack(spacing: 10) {
				Image(systemName: "wifi.slash")
					.font(.body)
				Text("Mất kết nối internet")
					.font(.subheadline)
					.fontWeight(.medium)
				Spacer()
			}
			.foregroundColor(.white)
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.background(Color.red.gradient)
			.transition(.move(edge: .top).combined(with: .opacity))
		}
	}
}
