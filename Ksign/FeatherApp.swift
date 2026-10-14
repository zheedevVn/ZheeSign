//
//  FeatherApp.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import OSLog
import IDeviceSwift
import UserNotifications

@main
struct FeatherApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	let heartbeat = HeartbeatManager.shared
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject var accentColorManager = AccentColorManager.shared
    @StateObject var extractManager = ExtractManager.shared
	@StateObject var logsManager = LogsManager.shared
	let storage = Storage.shared
	@ObservedObject var auth = ZheeAuthManager.shared
	@StateObject var appLock = ZheeAppLockManager.shared
	@Environment(\.scenePhase) var scenePhase
	@State private var hasBeenActive = false
	@State private var showSplash = true

	var body: some Scene {
		WindowGroup {
			Group {
				if !auth.isLoggedIn {
					ZheeLoginView()
				} else {
					VStack(spacing: 0) {
						ZheeUpdateBanner()
						ExtractHeaderView(extractManager: extractManager)
							.transition(.move(edge: .top).combined(with: .opacity))
						DownloadHeaderView(downloadManager: downloadManager)
							.transition(.move(edge: .top).combined(with: .opacity))
						VariedTabbarView()
							.environment(\.managedObjectContext, storage.context)
							.onOpenURL(perform: _handleURL)
							.transition(.move(edge: .top).combined(with: .opacity))
					}
					.animation(.smooth, value: downloadManager.manualDownloads.description)
					.animation(.smooth, value: extractManager.extractItems.description)
				}
			}
			.overlay {
				// Chỉ hiện màn khóa sau khi splash xong - tránh Face ID đè lên animation
				if appLock.isLocked && !showSplash {
					ZheeLockScreenView()
						.transition(.opacity)
				}
			}
			.overlay {
				// Che nội dung khi app không còn active - như app ngân hàng
				// Dùng != .active (bao gồm .inactive) vì iOS chụp snapshot trước khi vào .background
				if hasBeenActive && scenePhase != .active {
					ZStack {
						// Blur mờ toàn bộ nội dung bên dưới
						VisualEffectBlur(style: .systemMaterial)
							.ignoresSafeArea()
					}
					.transition(.opacity)
				}
			}
			.onChange(of: scenePhase) { phase in
				switch phase {
				case .active:
					hasBeenActive = true
					ZheeAppLockManager.shared.appDidBecomeActive()
				case .background:
					ZheeAppLockManager.shared.appDidEnterBackground()
				default:
					break
				}
			}
			.animation(.spring(response: 0.6, dampingFraction: 0.75), value: auth.isLoggedIn)
			.onReceive(accentColorManager.objectWillChange) { _ in
				accentColorManager.updateGlobalTintColor()
			}
			.onAppear {
				accentColorManager.updateGlobalTintColor()
				if logsManager.isCapturing { logsManager.startCapture() }
				// Splash 2.5s rồi mờ dần
				DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
					withAnimation(.easeOut(duration: 0.4)) {
						showSplash = false
					}
				}
			}
			.overlay {
				if showSplash {
					ZheeSplashView()
						.transition(.opacity)
				}
			}
		}
	}
	
	private func _handleURL(_ url: URL) {
		if url.scheme == "ksign" {
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				_ = DownloadManager.shared.startDownload(from: downloadURL, id: "FeatherManualDownload_\(UUID().uuidString)")
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
					FR.handlePackageFile(url) { _ in }
				} else {
					FR.handlePackageFile(url) { _ in }
				}
				
				return
			}
			
            if url.pathExtension == "ksign" {
                UIAlertController.showAlertWithOk(title: .localized("错误"), message: .localized("自 v1.5.1 起不再支持 Ksign 证书文件（.ksign），请改用 .p12 与 .mobileprovision。"))
            }
		}
	}
	
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Hiện thông báo cả khi app đang mở
        UNUserNotificationCenter.current().delegate = self
        
        // Đăng ký Background Fetch để check bản mới khi app ở nền
        UIApplication.shared.setMinimumBackgroundFetchInterval(1800) // 30 phút
        
        // Kiểm tra bảo mật: chặn debug/Frida
        if !ZheeSecurity.validateEnvironment() {
            // Phát hiện tấn công — thoát ngay
            exit(0)
        }
        
        _createPipeline()
        _createSourcesDirectory()
        if !UserDefaults.standard.bool(forKey: "hasInitializedBuiltInSources") {
            _initializeBuiltInSources()
            UserDefaults.standard.set(true, forKey: "hasInitializedBuiltInSources")
        }
        
        _clean()
        
        _copyServerCertificates()
        _addDefaultCertificates()

#if SERVER
        // fallback just in case xd
        _downloadSSLCertificates()
#endif
        return true
    }
    
    // Hiện banner thông báo cả khi app đang mở
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // Background Fetch — iOS đánh thức app để check bản mới, gửi thông báo
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let manager = ZheeUpdateManager()
        manager.checkForUpdates()
        // Đợi 3s để request xong rồi báo
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            completionHandler(manager.updateAvailable ? .newData : .noData)
        }
    }
    
    private func _initializeBuiltInSources() { 
        Storage.shared.addBuiltInSources()
    }
    
    private func _createPipeline() {
        DataLoader.sharedUrlCache.diskCapacity = 0
        
        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = {
                let config = URLSessionConfiguration.default
                config.urlCache = nil
                return DataLoader(configuration: config)
            }()
            let dataCache = try? DataCache(name: "thewonderofyou.Feather.datacache") // disk cache
            let imageCache = Nuke.ImageCache() // memory cache
            dataCache?.sizeLimit = 500 * 1024 * 1024
            imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.dataLoader = dataLoader
            $0.dataCachePolicy = .automatic
            $0.isStoringPreviewsInMemoryCache = false
        }
        
        ImagePipeline.shared = pipeline
    }
    
    private func _createSourcesDirectory() {
        let fileManager = FileManager.default
        
        let appDirectory = URL.documentsDirectory.appendingPathComponent("App")
        try? fileManager.createDirectoryIfNeeded(at: appDirectory)
        
        let directories = ["Signed", "Unsigned", "Archives", "Server", "Tweaks"].map {
            appDirectory.appendingPathComponent($0)
        }
        
        for url in directories {
            try? fileManager.createDirectoryIfNeeded(at: url)
        }
    }
    
    private func _clean() {
        let fileManager = FileManager.default
        let tmpDirectory = fileManager.temporaryDirectory
        
        if let files = try? fileManager.contentsOfDirectory(atPath: tmpDirectory.path()) {
            for file in files {
                try? fileManager.removeItem(atPath: tmpDirectory.appendingPathComponent(file).path())
            }
        }
    }
    
    private func _copyServerCertificates() {
        let fileManager = FileManager.default
        let serverDirectory = URL.documentsDirectory.appendingPathComponent("App/Server")
        
        try? fileManager.createDirectoryIfNeeded(at: serverDirectory)
        
        let filesToCopy = ["server.crt", "server.pem", "commonName.txt"]
        
        for fileName in filesToCopy {
            guard let bundleURL = Bundle.main.url(forResource: fileName.components(separatedBy: ".").first!, withExtension: fileName.components(separatedBy: ".").last!) else {
                print("File \(fileName) not found in app bundle")
                continue
            }
            
            let destinationURL = serverDirectory.appendingPathComponent(fileName)
            
            try? fileManager.removeItem(at: destinationURL)
            
            do {
                try fileManager.copyItem(at: bundleURL, to: destinationURL)
            } catch {
                print("Error copying \(fileName): \(error)")
            }
        }
    }
    
    private func _addDefaultCertificates() {
            guard
                UserDefaults.standard.bool(forKey: "feather.didImportDefaultCertificates") == false,
                let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
            else {
                return
            }
            
            do {
                let folderContents = try FileManager.default.contentsOfDirectory(
                    at: signingAssetsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for folderURL in folderContents {
                    guard folderURL.hasDirectoryPath else { continue }
                    
                    let certName = folderURL.lastPathComponent
                    
                    let p12Url = folderURL.appendingPathComponent("cert.p12")
                    let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
                    let passwordUrl = folderURL.appendingPathComponent("cert.txt")
                    
                    guard
                        FileManager.default.fileExists(atPath: p12Url.path),
                        FileManager.default.fileExists(atPath: provisionUrl.path),
                        FileManager.default.fileExists(atPath: passwordUrl.path)
                    else {
                        Logger.misc.warning("Skipping \(certName): missing required files")
                        continue
                    }
                    
                    let password = try String(contentsOf: passwordUrl, encoding: .utf8)
                    
                    FR.handleCertificateFiles(
                        p12URL: p12Url,
                        provisionURL: provisionUrl,
                        p12Password: password,
                        certificateName: certName,
                    ) { _ in
                        
                    }
                }
                UserDefaults.standard.set(true, forKey: "feather.didImportDefaultCertificates")
            } catch {
                Logger.misc.error("Failed to list signing-assets: \(error)")
            }
        }

#if SERVER
    private func _downloadSSLCertificates() {
        let serverURL = "https://backloop.dev/pack.json"
        
        FR.downloadSSLCertificates(from: serverURL) { success in
            if success {
                print("SSL certificates downloaded successfully")
            } else {
                print("Failed to download SSL certificates")
            }
        }
    }
#endif
}

// MARK: - Blur che nội dung khi app inactive
struct VisualEffectBlur: UIViewRepresentable {
	var style: UIBlurEffect.Style = .systemMaterial
	
	func makeUIView(context: Context) -> UIVisualEffectView {
		UIVisualEffectView(effect: UIBlurEffect(style: style))
	}
	
	func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
		uiView.effect = UIBlurEffect(style: style)
	}
}
