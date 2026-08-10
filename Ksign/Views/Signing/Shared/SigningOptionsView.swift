//
//  SigningOptionsSharedView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningOptionsView: View {
    @Binding var options: Options
    var temporaryOptions: Options?
    
    // MARK: Body
    var body: some View {
        if (temporaryOptions == nil) {
            NBSection(.localized("保护")) {
                _toggle(.localized("PPQ 保护"),
                        systemImage: "shield.fill",
                        isOn: $options.ppqProtection,
                        temporaryValue: temporaryOptions?.ppqProtection
                )
                #warning("add dynamic protect (itunes api)")
//                _toggle("Dynamic Protection",
//                        systemImage: "shield.lefthalf.filled",
//                        isOn: $options.dynamicProtection,
//                        temporaryValue: temporaryOptions?.dynamicProtection
//                )
//                    .disabled(!options.ppqProtection)
            } footer: {
                Text(.localized("开启任何保护都会在你签名的应用包名后追加一段随机字符串，以防 Apple ID 被 Apple 标记。但如果你使用的是签名服务，可忽略此项。"))
            }
            Section {
                _toggle(.localized("签名后移除应用"),
                        systemImage: "trash",
                        isOn: $options.removeApp,
                        temporaryValue: temporaryOptions?.removeApp
                )
            } footer: {
                Text(.localized("签名后移除应用（针对已下载的应用）"))
            }
        } else {
            NBSection(.localized("通用")) {
                _picker(.localized("外观"),
                        systemImage: "paintpalette",
                        selection: $options.appAppearance,
                        values: Options.appAppearanceValues,
                        id: \.description
                )
                
                _picker(.localized("最低要求"),
                        systemImage: "ruler",
                        selection: $options.minimumAppRequirement,
                        values: Options.appMinimumAppRequirementValues,
                        id: \.description
                )
            }
            Section {
                _toggle(.localized("签名后移除应用"),
                        systemImage: "trash",
                        isOn: $options.removeApp,
                        temporaryValue: temporaryOptions?.removeApp
                )
                _toggle(.localized("仅修改（不签名）"),
                        systemImage: "pencil.slash",
                        isOn: $options.onlyModify,
                        temporaryValue: temporaryOptions?.onlyModify
                )
            }
        }
        
        NBSection(.localized("应用功能")) {
            _toggle(.localized("文件共享"),
                    systemImage: "folder.badge.person.crop",
                    isOn: $options.fileSharing,
                    temporaryValue: temporaryOptions?.fileSharing
            )
            
            _toggle(.localized("iTunes 文件共享"),
                    systemImage: "music.note.list",
                    isOn: $options.itunesFileSharing,
                    temporaryValue: temporaryOptions?.itunesFileSharing
            )
            
            _toggle("ProMotion",
                    systemImage: "speedometer",
                    isOn: $options.proMotion,
                    temporaryValue: temporaryOptions?.proMotion
            )
            
            _toggle("游戏模式",
                    systemImage: "gamecontroller",
                    isOn: $options.gameMode,
                    temporaryValue: temporaryOptions?.gameMode
            )
            
            _toggle(.localized("iPad 全屏"),
                    systemImage: "ipad.landscape",
                    isOn: $options.ipadFullscreen,
                    temporaryValue: temporaryOptions?.ipadFullscreen
            )
        } footer: {
            Text(.localized("这些选项会改变应用的行为"))
        }
        
        NBSection(.localized("移除")) {
            _toggle(.localized("移除支持的设备"),
                    systemImage: "iphone.slash",
                    isOn: $options.removeSupportedDevices,
                    temporaryValue: temporaryOptions?.removeSupportedDevices
            )
            
            _toggle(.localized("移除 URL Scheme"),
                    systemImage: "ellipsis.curlybraces",
                    isOn: $options.removeURLScheme,
                    temporaryValue: temporaryOptions?.removeURLScheme
            )
            
            _toggle(.localized("移除描述文件"),
                    systemImage: "doc.badge.gearshape",
                    isOn: $options.removeProvisioning,
                    temporaryValue: temporaryOptions?.removeProvisioning
            )
            
            _toggle(.localized("移除 Watch 占位"),
                    systemImage: "applewatch.slash",
                    isOn: $options.removeWatchPlaceholder,
                    temporaryValue: temporaryOptions?.removeWatchPlaceholder
            )
        } footer: {
            Text(.localized("这些选项会移除未签名 IPA 中的部分内容"))
        }
        
        Section {
            _toggle(.localized("强制本地化"),
                    systemImage: "character.bubble",
                    isOn: $options.changeLanguageFilesForCustomDisplayName,
                    temporaryValue: temporaryOptions?.changeLanguageFilesForCustomDisplayName
            )
        } footer: {
            Text(.localized("强制应用使用本地化语言"))
        }
        
        NBSection(.localized("高级")) {
            _toggle(.localized("Adhoc 签名"),
                    systemImage: "signature",
                    isOn: $options.doAdhocSigning,
                    temporaryValue: temporaryOptions?.doAdhocSigning
            )
        } footer: {
            Text(.localized("仅在使用 Ad Hoc 证书时启用"))
        }
        
        NBSection(.localized("实验性")) {
            _toggle(
                .localized("用 ElleKit 替换 Substrate"),
                systemImage: "pencil",
                isOn: $options.experiment_replaceSubstrateWithEllekit,
                temporaryValue: temporaryOptions?.experiment_replaceSubstrateWithEllekit
            )
            
            _toggle(
                .localized("启用液态玻璃"),
                systemImage: "26.circle",
                isOn: $options.experiment_supportLiquidGlass,
                temporaryValue: temporaryOptions?.experiment_supportLiquidGlass
            )
			.onChange(of: options.experiment_supportLiquidGlass) { newValue in
				if newValue {
					options.experiment_disableLiquidGlass = false
				}
			}
        } footer: {
            Text(.localized("此选项会强制让应用尝试使用 iOS 26 引入的液态玻璃新设计。由于各应用所用框架不同，可能并不适用于所有应用。"))
        }

		Section {
			_toggle(
				.localized("禁用液态玻璃"),
				systemImage: "18.circle",
				isOn: $options.experiment_disableLiquidGlass,
				temporaryValue: temporaryOptions?.experiment_disableLiquidGlass
			)
			.onChange(of: options.experiment_disableLiquidGlass) { newValue in
				if newValue {
					options.experiment_supportLiquidGlass = false
				}
			}
		} footer: {
			Text(.localized("此选项会尝试在 iOS 26 上为支持的应用禁用液态玻璃（可能不适用于所有应用）。"))
		}
    }
    
    @ViewBuilder
    private func _picker<SelectionValue, T>(
        _ title: String,
        systemImage: String,
        selection: Binding<SelectionValue>,
        values: [T],
        id: KeyPath<T, SelectionValue>
    ) -> some View where SelectionValue: Hashable {
        Picker(selection: selection) {
            ForEach(values, id: id) { value in
                Text(String(describing: value))
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
    
    @ViewBuilder
    private func _toggle(
        _ title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        temporaryValue: Bool? = nil
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                if let tempValue = temporaryValue, tempValue != isOn.wrappedValue {
                    Text(title)
                } else {
                    Text(title)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
