//
//  ArchiveView.swift
//  Feather
//
//  Created by samara on 6.05.2025.
//

import SwiftUI
import Zip
import NimbleViews

struct ArchiveView: View {
	@AppStorage("Feather.compressionLevel") private var _compressionLevel: Int = ZipCompression.DefaultCompression.rawValue
	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = true
	@AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false
	@AppStorage("Feather.extractionLibrary") private var _extractionLibrary: String = "Zip"
    
    var body: some View {
		NBList(.localized("压缩与解压")) {
			Section {
				Picker(.localized("压缩级别"), systemImage: "archivebox", selection: $_compressionLevel) {
					ForEach(ZipCompression.allCases, id: \.rawValue) { level in
						Text(level.label).tag(level)
					}
				}
			}
			
			Section {
				Toggle(.localized("导出时显示分享面板"), systemImage: "square.and.arrow.up", isOn: $_useShareSheet)
			} footer: {
				Text(.localized("开启后，导出到文件时会弹出分享面板。"))
			}
            
            Section {
                Toggle(.localized("使用上次复制的位置"), systemImage: "clock.arrow.circlepath", isOn: $_useLastExportLocation)
            } footer: {
                Text(.localized("是否记住上次复制/移动文件的目标位置，否则默认使用 Ksign 的 Documents 文件夹。"))
            }

            Section {
                Picker(.localized("解压库"), systemImage: "archivebox.circle.fill", selection: $_extractionLibrary) {
                    ForEach(Options.extractionLibraryValues, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
            } footer: {
                Text(.localized("选择用于解压压缩包的库。文件较大或默认 Zip 失效时，推荐使用 ZIPFoundation。"))
            }
		}
    }
}
