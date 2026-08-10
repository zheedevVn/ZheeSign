//
//  SettingsTunnelView.swift
//  Feather (idevice)
//
//  Created by samara on 29.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift

// MARK: - View
struct TunnelView: View {
	@State private var _isImportingPairingPresenting = false
	
	@State var doesHavePairingFile = false
	
	// MARK: Body
    var body: some View {
		Group {
			Section {
				if #available(iOS 17.4, *) {
				} else {
					_tunnelInfo()
					TunnelHeaderView()
				}
			} footer: {
				if doesHavePairingFile {
					Text(.localized("看来你已经拿到配对文件了！"))
				} else {
					Text(.localized("未找到配对文件，请先导入。"))
				}
			}
			
			Section {
				Button(.localized("导入配对文件"), systemImage: "square.and.arrow.down") {
					_isImportingPairingPresenting = true
				}
				if #available(iOS 17.4, *) {
				} else {
					Button(.localized("重启心跳"), systemImage: "arrow.counterclockwise") {
						HeartbeatManager.shared.start(true)
						
						DispatchQueue.global(qos: .userInitiated).async {
							if !HeartbeatManager.shared.checkSocketConnection().isConnected {
								DispatchQueue.main.async {
									UIAlertController.showAlertWithOk(
										title: "Socket",
										message: "无法连接到 TCP。请确保已开启本地回环 VPN，并处于 Wi-Fi 或飞行模式。"
									)
								}
							}
						}
					}
				}
			}
			
			NBSection(.localized("帮助")) {
				Button(.localized("配对文件指南"), systemImage: "questionmark.circle") {
					UIApplication.open("https://github.com/claration/Impactor#pairing-file")
				}
				Button(.localized("下载 LocalDevVPN"), systemImage: "arrow.down.app") {
					UIApplication.open("https://apps.apple.com/us/app/localdevvpn/id6755608044")
				}
			}
		}
		.sheet(isPresented: $_isImportingPairingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes:  [.xmlPropertyList, .plist, .mobiledevicepairing],
				onDocumentsPicked: { urls in
					guard let selectedFileURL = urls.first else { return }
					FR.movePairing(selectedFileURL)
					doesHavePairingFile = true
				}
			)
		}
		.onAppear {
			if FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile()) {
				doesHavePairingFile = true
			} else {
				doesHavePairingFile = false
			}
		}
    }
	
	@ViewBuilder
	private func _tunnelInfo() -> some View {
		HStack {
			VStack(alignment: .leading, spacing: 6) {
				Text(.localized("心跳保活"))
					.font(.headline)
				Text(.localized("心跳保活在后台运行，重新打开应用或被触发时会重启。如果下方状态在跳动，说明运行正常。"))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		}
	}
}
