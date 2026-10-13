//
//  SettingsDonationCellView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

//#if !NIGHTLY && !DEBUG
import SwiftUI
import NimbleViews

struct SettingsDonationCellView: View {
	var site: String
	
	var body: some View {
		Section {
			VStack(spacing: 14) {
				_title()
				
				_benefit(
					.localized("支持我们"),
					.localized("通过赞助来支持我们！如果暂时无法赞助，帮忙宣传也是一种支持～"),
					systemName: "heart.fill"
				)
				
				Button() {
					UIApplication.open(site)
				} label: {
					_sheetButton(.localized("赞助"))
				}
				.frame(height: 45)
			}
			.padding(.vertical, 12)
			.buttonStyle(.plain)
		}
	}
	
	@ViewBuilder
	private func _title() -> some View {
		VStack(alignment: .center, spacing: 12) {
            Image(uiImage: (UIImage(named: "ZheeLogo"))!).resizable().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			
			Text(.localized("赞助"))
				.font(.title)
				.bold()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
	}
	
	@ViewBuilder
	private func _benefit(
		_ title: String,
		_ desc: String,
		systemName: String
	) -> some View {
		HStack(alignment: .center, spacing: 14) {
			Image(systemName: systemName)
				.font(.system(size: 32))
				.foregroundStyle(.tint)
				.frame(width: 39, alignment: .center)
			
			NBTitleWithSubtitleView(
				title: title,
				subtitle: desc
			)
		}
	}
	
	@ViewBuilder
	private func _sheetButton(_ title: String) -> some View {
		Text(title)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Color.accentColor)
			.foregroundColor(.white)
			.clipShape(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
			)
			.bold()
	}
}

//#endif
