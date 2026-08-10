//
//  CertificatesAddView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	
	@State private var _p12Data: Data? = nil
	@State private var _provisionData: Data? = nil
	@State private var _isFromKsign: Bool = false
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isImportingKsignPresenting = false
	@State private var _isPasswordAlertPresenting = false
	@State private var _errorMessage: String = ""
	@State private var _isErrorPresenting = false
	
	var saveButtonDisabled: Bool {
		if _isFromKsign {
			return _p12Data == nil || _provisionData == nil
		} else {
			return _p12URL == nil || _provisionURL == nil
		}
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("新建证书"), displayMode: .inline) {
			Form {
				NBSection(.localized("文件")) {
					_importButton(.localized("导入证书文件"), file: _p12URL, hasData: _p12Data) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("导入描述文件"), file: _provisionURL, hasData: _provisionData) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				NBSection(.localized("密码")) {
					SecureField(.localized("输入密码"), text: $_p12Password)
				} footer: {
					Text(.localized("输入与私钥对应的密码。若无需密码则留空。"))
				}
				
				Section {
					TextField(.localized("昵称（可选）"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("保存"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.p12],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._p12URL = selectedFileURL
						self._isFromKsign = false
					}
				)
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.mobileProvision],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._provisionURL = selectedFileURL
						self._isFromKsign = false
					}
				)
			}
			.alert(isPresented: $_isPasswordAlertPresenting) {
				Alert(
					title: Text(.localized("密码错误")),
					message: Text(.localized("请检查密码后重试。")),
					dismissButton: .default(Text(.localized("好的")))
				)
			}
			.alert(isPresented: $_isErrorPresenting) {
				Alert(
					title: Text(.localized("导入失败")),
					message: Text(_errorMessage),
					dismissButton: .default(Text(.localized("好的")))
				)
			}
		}
	}
}

// MARK: - Extension: View
extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		hasData: Data? = nil,
		action: @escaping () -> Void
	) -> some View {
		Button(title) {
			action()
		}
		.foregroundColor((file == nil && hasData == nil) ? .accentColor : .disabled())
		.disabled(file != nil || hasData != nil)
		.animation(.easeInOut(duration: 0.3), value: file != nil || hasData != nil)
	}
}

// MARK: - Extension: View (import)
extension CertificatesAddView {
	private func _saveCertificate() {
        guard
            let p12URL = _p12URL,
            let provisionURL = _provisionURL,
            FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
        else {
            _isPasswordAlertPresenting = true
            return
        }
        
        FR.handleCertificateFiles(
            p12URL: p12URL,
            provisionURL: provisionURL,
            p12Password: _p12Password,
            certificateName: _certificateName
        ) { _ in
            dismiss()
        }
	}
}



