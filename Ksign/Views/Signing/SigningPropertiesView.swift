//
//  SigningAppPropertiesView.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningPropertiesView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var text: String = ""
	
	var saveButtonDisabled: Bool {
		text == initialValue
	}
	
	var title: String
	var initialValue: String 
	var certAppId: String? = nil
	@Binding var bindingValue: String?
	
	// MARK: Body
	var body: some View {
        NBList(title) {
            TextField(initialValue, text: $text)
                .textInputAutocapitalization(.none)
            if certAppId != nil {
                Section {
                    Button {
                        text = certAppId ?? ""
                    } label: {
                        Text(.localized("匹配证书的 App ID"))
                    }
                    .disabled(certAppId == nil)
                } footer: {
                    Text(.localized("使用证书的 App ID，让应用能使用证书权限对应的功能。"))
                }
            }
        }
		.toolbar {
			NBToolbarButton(
				.localized("保存"),
				style: .text,
				placement: .topBarTrailing,
				isDisabled: saveButtonDisabled
			) {
				if !saveButtonDisabled {
					bindingValue = text
					dismiss()
				}
			}
		}
		.onAppear {
			text = initialValue
		}
	}
}
