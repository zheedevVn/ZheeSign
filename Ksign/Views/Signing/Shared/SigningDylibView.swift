//
//  SigningOptionsDylibSharedView.swift
//  Feather
//
//  Created by samara on 19.04.2025.
//

import SwiftUI
import NimbleViews
import ZsignSwift

// MARK: - View
struct SigningDylibView: View {
	@State private var _dylibs: [String] = []
	@State private var _hiddenDylibCount: Int = 0
	
	var app: AppInfoPresentable
	@Binding var options: Options?
	
	var body: some View {
		NBList(.localized("动态库"), type: .list) {
			Section {
				ForEach(_dylibs, id: \.self) { dylib in
					SigningToggleCellView(
						title: dylib,
						options: $options,
						arrayKeyPath: \.disInjectionFiles
					)
				}
			}
			.disabled(options == nil)
			
			NBSection(.localized("隐藏")) {
				Text(verbatim: .localized("另有 %lld 个系统必需的动态库未显示", arguments: _hiddenDylibCount))
					.font(.footnote)
					.foregroundColor(.disabled())
			}
		}
		.onAppear(perform: _loadDylibs)
	}
}

// MARK: - Extension: View
extension SigningDylibView {
	private func _loadDylibs() {
		guard let path = Storage.shared.getAppDirectory(for: app) else { return }
		
		let bundle = Bundle(url: path)
		let execPath = path.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		let allDylibs = Zsign.listDylibs(appExecutable: execPath).map { $0 as String }
		
		_dylibs = allDylibs.filter { $0.hasPrefix("@rpath") || $0.hasPrefix("@executable_path") }
		_hiddenDylibCount = allDylibs.count - _dylibs.count
	}
}
