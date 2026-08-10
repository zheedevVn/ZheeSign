//
//  AppearanceView.swift
//  Feather
//
//  Created by samara on 7.05.2025.
//

import SwiftUI
import NimbleViews

struct AppearanceView: View {
    @AppStorage("Feather.userInterfaceStyle") private var _userIntefacerStyle: Int = UIUserInterfaceStyle.unspecified.rawValue
    
	@AppStorage("Feather.libraryCellAppearance") private var _libraryCellAppearance: Int = 0
	
	private let _libraryCellAppearanceMethods: [String] = [
		.localized("标准"),
		.localized("胶囊样式")
	]
	
	@AppStorage("Feather.storeCellAppearance") private var _storeCellAppearance: Int = 1
	
	private let _storeCellAppearanceMethods: [String] = [
		.localized("标准"),
		.localized("详细描述")
	]
	
	@AppStorage("Feather.accentColor") private var _selectedAccentColor: Int = 0
	@StateObject private var accentColorManager = AccentColorManager.shared
    
	private let _accentColors: [(name: String, color: Color)] = [
		(.localized("默认"), Color(red: 0x53/255, green: 0x94/255, blue: 0xF7/255)),
		(.localized("樱桃红"), Color(red: 0xFF/255, green: 0x8B/255, blue: 0x92/255)),
		(.localized("红色"), .red),
		(.localized("橙色"), .orange),
		(.localized("黄色"), .yellow),
		(.localized("绿色"), .green),
		(.localized("蓝色"), .blue),
		(.localized("紫色"), .purple),
		(.localized("粉色"), .pink),
		(.localized("靛蓝"), .indigo),
		(.localized("薄荷绿"), .mint),
		(.localized("青色"), .cyan),
		(.localized("蓝绿色"), .teal)
	]
	
	private var currentAccentColor: Color {
		accentColorManager.currentAccentColor
	}

    var body: some View {
        NBList(.localized("外观")) {
            
            Section {
                Picker(.localized("外观"), selection: $_userIntefacerStyle) {
                    ForEach(UIUserInterfaceStyle.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
			
			NBSection(.localized("源")) {
                _storePreview()
				Picker(.localized("商店单元格外观"), selection: $_storeCellAppearance) {
					ForEach(_storeCellAppearanceMethods.indices, id: \.description) { index in
						Text(_storeCellAppearanceMethods[index]).tag(index)
					}
				}
				.pickerStyle(.inline)
                .labelsHidden()
			}
			
			NBSection(.localized("强调色")) {
				_accentColorPreview()
				Picker(.localized("强调色"), selection: $_selectedAccentColor) {
					ForEach(_accentColors.indices, id: \.description) { index in
						HStack {
							Circle()
								.fill(_accentColors[index].color)
								.frame(width: 20, height: 20)
							Text(_accentColors[index].name)
						}
						.tag(index)
					}
				}
				.pickerStyle(.inline)
				.labelsHidden()
			}
		}
        .onChange(of: _userIntefacerStyle) { value in
            if let style = UIUserInterfaceStyle(rawValue: value) {
                UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
            }
        }
		.onChange(of: _selectedAccentColor) { _ in
			accentColorManager.updateGlobalTintColor()
		}
    }
	
	@ViewBuilder
	private func _libraryPreview() -> some View {
		HStack(spacing: 9) {
			Image(uiImage: (UIImage(named: Bundle.main.iconFileName ?? ""))! )
				.appIconStyle(size: 57)
			
			NBTitleWithSubtitleView(
				title: Bundle.main.name,
				subtitle: "\(Bundle.main.version) • \(Bundle.main.bundleIdentifier ?? "")",
				linelimit: 0
			)
			
			FRExpirationPillView(
				title: .localized("安装"),
				showOverlay: _libraryCellAppearance == 0,
				expiration: Date.now.expirationInfo()
			).animation(.spring, value: _libraryCellAppearance)
		}
	}
    
    @ViewBuilder
    private func _storePreview() -> some View {
        VStack {
            HStack(spacing: 9) {
                Image(uiImage: (UIImage(named: Bundle.main.iconFileName ?? ""))! )
                    .appIconStyle(size: 57)
                
                NBTitleWithSubtitleView(
                    title: Bundle.main.name,
                    subtitle: "\(Bundle.main.version) • " + .localized("一个超棒的应用"),
                    linelimit: 0
                )
            }
            
            if _storeCellAppearance != 0 {
                Text(.localized("一个超棒的应用"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(18)
                    .padding(.top, 2)
            }
        }
        .animation(.spring, value: _storeCellAppearance)
    }
	
	@ViewBuilder
	private func _accentColorPreview() -> some View {
		HStack(spacing: 9) {
			Circle()
				.fill(currentAccentColor)
				.frame(width: 57, height: 57)
			
			NBTitleWithSubtitleView(
				title: .localized("强调色"),
				subtitle: .localized("这是当前的强调色"),
				linelimit: 0
			)
		}
	}
}
