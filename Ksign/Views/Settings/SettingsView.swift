//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SettingsView: View {
    @AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>
    
    private var selectedCertificate: CertificatePair? {
        guard
            _storedSelectedCert >= 0,
            _storedSelectedCert < _certificates.count
        else {
            return nil
        }
        return _certificates[_storedSelectedCert]
    }
    
    
	private let _donationsUrl = "https://github.com/sponsors/zheedevVn"
	private let _githubUrl = "https://github.com/zheedevVn/ZheeSign"
	// MARK: Body
    var body: some View {
		NBNavigationView(.localized("设置")) {
			Form {
//				#if !NIGHTLY && !DEBUG
				SettingsDonationCellView(site: _donationsUrl)
//				#endif
				
				ZheeProfileView()
				ZheeUpdateView()
				
				_feedback()
				_utilities()
				
				Section {
                    NavigationLink(destination: AppIconView()) {
                        Label(.localized("应用图标"), systemImage: "app.badge")
                    }
					NavigationLink(destination: AppearanceView()) {
                        Label(.localized("外观"), systemImage: "paintbrush")
                    }
				}
                
                NBSection(.localized("证书")) {
                    
                    if let cert = selectedCertificate {
                        CertificatesCellView(cert: cert)
                    } else {
                        Text(.localized("暂无证书"))
                            .font(.footnote)
                            .foregroundColor(.disabled())
                    }
                    NavigationLink(destination: CertificatesView()) {
                        Label(.localized("证书"), systemImage: "signature")
                    }
                 
                } footer: {
                    Text(.localized("添加并管理用于给应用签名的证书。"))
                }
				
				NBSection(.localized("功能")) {
                    NavigationLink(destination: LogsView(manager: LogsManager.shared)) {
                        Label(.localized("日志"), systemImage: "apple.terminal")
                    }
					NavigationLink(destination: AppFeaturesView()) {
                        Label(.localized("应用功能"), systemImage: "sparkles")
                    }
					NavigationLink(destination: ConfigurationView()) {
                        Label(.localized("签名选项"), systemImage: "gear")
                    }
					NavigationLink(destination: ArchiveView()) {
                        Label(.localized("压缩与解压"), systemImage: "archivebox")
                    }
					NavigationLink(destination: InstallationView()) {
                        Label(.localized("安装"), systemImage: "server.rack")
                    }
				}

				
				_directories()
                
                Section {
                    NavigationLink(destination: ResetView()) {
                        Label(.localized("重置"), systemImage: "trash")
                    }
                } footer: {
                    Text("Sẽ đặt lại nguồn, chứng chỉ, ứng dụng và nội dung chung của ứng dụng.")
                }

            }
        }
    }
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(destination: AboutNyaView()) {
                Label(.localized("关于"), systemImage: "info.circle")
            }
			Button(.localized("Telegram 频道"), systemImage: "paperplane.circle") {
				UIApplication.open("https://t.me/zheevipv1")
			}
			Button(.localized("GitHub 仓库"), systemImage: "safari") {
				UIApplication.open(_githubUrl)
			}
		}
	}
	
	@ViewBuilder
	private func _utilities() -> some View {
		Section("Trợ năng") {
			NavigationLink(destination: ZheePrivacySettingsView()) {
				Label("Cài đặt và quyền riêng tư", systemImage: "hand.raised")
			}
			NavigationLink(destination: WebBrowserView()) {
				Label("Trình duyệt web", systemImage: "globe")
			}
			NavigationLink(destination: ZheePythonView()) {
				Label("Python", systemImage: "chevron.left.forwardslash.chevron.right")
			}
		}
	}
	
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("其他")) {
			Button(.localized("打开 Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("打开压缩包"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("除证书外，Ksign 的所有文件都存放在 Documents 目录下，以下是相关的快捷入口。"))
		}
	}
}
