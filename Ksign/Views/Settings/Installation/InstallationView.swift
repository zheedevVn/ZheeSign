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
                Text("Máy chủ (khuyên dùng):\nCài đặt ứng dụng qua máy chủ lưu trữ cục bộ và giao thức itms-services://.\n\nIDevice (nâng cao):\nDùng VPN với tệp ghép đôi, ghi vào AFC và gọi thủ công installd, đồng thời theo dõi tiến độ cài đặt qua callback.\nƯu điểm: rất ổn định, không cần chứng chỉ SSL hay máy chủ lưu trữ ngoài, cách hoạt động giống như trên máy tính.")
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

