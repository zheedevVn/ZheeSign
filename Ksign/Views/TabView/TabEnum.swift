//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case files
	case sources
	case library
	case settings
	case certificates
	case appstore
    case downloader
	var title: String {
		switch self {
        case .files:        return .localized("文件")
		case .sources:     	return .localized("源")
		case .library: 		return .localized("资源库")
		case .settings: 	return .localized("设置")
		case .certificates:	return .localized("证书")
		case .appstore: 	return .localized("应用商店")
        case .downloader:   return .localized("下载")
		}
	}
	
	var icon: String {
		switch self {
        case .files:        return "folder.fill"
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .appstore: 	return "plus.app.fill"
        case .downloader:    return "square.and.arrow.down.fill"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
        case .files: FilesView()
		case .sources: SourcesView()
		case .library: LibraryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("证书")) { CertificatesView() }
		case .appstore: AppstoreView()
        case .downloader: DownloaderView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
            .files,
            .library,
            .appstore,
            .downloader,
			.settings,
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}
