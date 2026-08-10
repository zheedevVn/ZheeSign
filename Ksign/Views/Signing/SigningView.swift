//
//  SigningView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import PhotosUI
import NimbleViews

// MARK: - View
struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@Namespace var _namespace

	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isLogsPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	
	var signAndInstall: Bool = false
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	private func _getCertAppID() -> String? {
		guard
			let cert = _selectedCert(),
			let decoded = Storage.shared.getProvisionFileDecoded(for: cert),
			let entitlements = decoded.Entitlements,
			let appID = entitlements["application-identifier"]?.value as? String
		else {
			return nil
		}
		return appID.split(separator: ".").dropFirst().joined(separator: ".")
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable, signAndInstall: Bool = false) {
		self.app = app
		self.signAndInstall = signAndInstall
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
    var body: some View {
		NBNavigationView(app.name ?? .localized("未知"), displayMode: .inline) {
			Form {
				_customizationOptions(for: app)
				_cert()
				_customizationProperties(for: app)
			}
			.disabled(_isSigning)
			.safeAreaInset(edge: .bottom) {
				if _isSigning {
					Button() {
						_isLogsPresenting = true
					} label: {
						NBSheetButton(title: .localized("显示日志"))
					}
					.tint(.secondary)
					.compatMatchedTransitionSource(id: "showLogs", ns: _namespace)
				} else {
					Button() {
						_start()
					} label: {
						NBSheetButton(title: .localized("开始签名"))
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .dismiss)
				
				NBToolbarButton(
					.localized("重置"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.fullScreenCover(isPresented: $_isLogsPresenting ) {
				LogsView(manager: LogsManager.shared)
					.compatNavigationTransition(id: "showLogs", ns: _namespace)
			}
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.animation(.smooth, value: _isSigning)
		}
		.onAppear {
			// ppq protection
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
			
			if _optionsManager.options.prefix != nil || _optionsManager.options.suffix != nil {
				var name = app.name ?? ""
				
				if
					let dictName = _temporaryOptions.displayNames[name]
				{
					name = dictName
				}
				
				if let prefix = _optionsManager.options.prefix {
					name = prefix + name
				}
				
				if let suffix = _optionsManager.options.suffix {
					name = name + suffix
				}
				
				_temporaryOptions.appName = name
			}
		}
    }
}

// MARK: - Extension: View
extension SigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("自定义")) {
			Menu {
				Button(.localized("选择备用图标")) { _isAltPickerPresenting = true }
				Button(.localized("从“文件”选取")) { _isFilePickerPresenting = true }
				Button(.localized("从相册选取")) { _isImagePickerPresenting = true }
			} label: {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle(size: 55)
				} else {
					FRAppIconView(app: app, size: 55)
				}
			}
			
			_infoCell(.localized("名称"), desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("名称"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell(.localized("标识符"), desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("标识符"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					certAppId: _getCertAppID(),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell(.localized("版本"), desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("版本"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
	}
	
	@ViewBuilder
	private func _cert() -> some View {
		NBSection(.localized("签名")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("高级")) {
			DisclosureGroup(.localized("修改")) {
				NavigationLink(.localized("已有动态库")) {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink(String.localized("框架与插件")) {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				#if NIGHTLY || DEBUG
				NavigationLink(String.localized("权限")) {
					SigningEntitlementsView(
						bindingValue: $_temporaryOptions.appEntitlementsFile
					)
				}
				#endif
				NavigationLink(String.localized("插件")) {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink(String.localized("属性")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle(.localized("属性"))
			}
		}
	}
	
	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? .localized("未知"))
			}
		}
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard _selectedCert() != nil || _temporaryOptions.doAdhocSigning || _temporaryOptions.onlyModify else {
			UIAlertController.showAlertWithOk(
				title: .localized("暂无证书"),
				message: .localized("请前往设置，导入一个有效的证书"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isLogsPresenting = _optionsManager.options.signingLogs
		_isSigning = true
#if DEBUG
		LogsManager.shared.startCapture()
#endif
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { [self] error in
			if let error {
				let ok = UIAlertAction(title: .localized("关闭"), style: .cancel) { _ in
					dismiss()
				}
				
				UIAlertController.showAlert(
					title: .localized("签名"),
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				// Remove app after signed option thing
				if _temporaryOptions.removeApp && !app.isSigned {
					Storage.shared.deleteApp(for: app)
				}
                
				if signAndInstall {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("feather.installApp"),
                            object: nil
                        )
                    }
                }
				dismiss()
			}
		}
	}
}
