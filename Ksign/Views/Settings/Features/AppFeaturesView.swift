//
//  AppFeaturesView.swift
//  Ksign
//
//  Created by Nagata Asami on 10/10/25.
//

import SwiftUI
import NimbleViews
import UserNotifications

struct AppFeaturesView: View {
    @StateObject private var _optionsManager = OptionsManager.shared
    
    var body: some View {
        NBList(.localized("应用功能")) {
            Section {
                Toggle(isOn: $_optionsManager.options.backgroundAudio) {
                    Label(.localized("保持应用后台运行"), systemImage: "arrow.trianglehead.2.clockwise")
                }
            } footer: {
                Text(.localized("即使关闭应用也会保持后台运行，便于下载或安装 IPA。"))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.signingLogs) {
                    Label(.localized("签名时显示日志"), systemImage: "terminal")
                }
            } footer: {
                Text(.localized("开始签名时会显示签名过程的日志。"))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.notifications) {
                    Label(.localized("下载完成时通知"), systemImage: "bell")
                }
                .onChange(of: _optionsManager.options.notifications) { enabled in
                    _notificationsAuthorization(enabled)
                }
            } footer: {
                Text(.localized("下载完成时会通知你。"))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.saveAppStoreDownloadsToDownloadsFolder) {
                    Label(.localized("将应用商店的下载保存到“下载”文件夹"), systemImage: "square.and.arrow.down.fill")
                }
            } footer: {
                Text(.localized("将应用商店的下载保存到“下载”文件夹。关闭此项可减少磁盘占用。"))
            }
        }
        .onChange(of: _optionsManager.options) { _ in
            _optionsManager.saveOptions()
        }
    }

    private func _notificationsAuthorization(_ enabled: Bool) {
        guard enabled else { return }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        if !granted {
                            _optionsManager.options.notifications = false
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    _optionsManager.options.notifications = false
                    
                    let cancel = UIAlertAction(title: .localized("取消"), style: .cancel)
                    let ok = UIAlertAction(title: .localized("打开设置"), style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    UIAlertController.showAlert(
                        title: .localized("你已拒绝！"),
                        message: .localized("请前往设置，授予发送通知的权限。"),
                        actions: [cancel, ok]
                    )
                }
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }
}
