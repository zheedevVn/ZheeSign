//
//  InstallationView.swift
//  Feather
//
//  Created by samara on 3.06.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct InstallationView: View {
    @AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
    @State private var _showMethodChangedAlert = false

    private let _installationMethods: [String] = [
        .localized("服务器"),
        .localized("idevice")
    ]
    
    // MARK: Body
    var body: some View {
        NBList(.localized("安装")) {
            Section {
                Picker(.localized("安装方式"), systemImage: "arrow.down.app", selection: $_installationMethod) {
                    ForEach(_installationMethods.indices, id: \.description) { index in
                        Text(_installationMethods[index]).tag(index)
                    }
                }
            } footer: {
                Text("服务器（推荐）：\n通过本地托管的服务器和 itms-services:// 协议来安装应用。\n\nIDevice（高级）：\n使用 VPN 与配对文件，写入 AFC 并手动调用 installd，同时通过回调监控安装进度。\n优点：非常稳定，无需 SSL 证书或外部托管的服务器，工作方式与电脑类似。")
            }
            
            if _installationMethod == 0 {
                ServerView()
            } else if _installationMethod == 1 {
                TunnelView()
            }
        }
        .onChange(of: _installationMethod) { newValue in
            guard newValue == 1 else { return }
            _showMethodChangedAlert = true
        }
        .alert(.localized("高级安装方式"), isPresented: $_showMethodChangedAlert) {
            Button(.localized("切换回去"), role: .destructive) {
                _installationMethod = 0
            }
            Button(.localized("好的"), role: .cancel) {}
        } message: {
            Text(.localized("idevice 警告"))
        }


        .animation(.default, value: _installationMethod)
    }
}

