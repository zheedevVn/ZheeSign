//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

struct TabbarView: View {
	@State private var selectedTab: TabEnum = .sources

	var body: some View {
		ZStack(alignment: .top) {
			TabView(selection: $selectedTab) {
				ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
					TabEnum.view(for: tab)
						.tabItem {
							Label(tab.title, systemImage: tab.icon)
						}
						.tag(tab)
				}
			}
			// Banner mất mạng — trên cùng ở giữa, mọi tab
			ZheeOfflineBanner()
				.padding(.top, 8)
			
			// Nút nổi Twitter PiP — kéo thả, dán link tự tải
			ZheeFloatingTwitter()
		}
	}
}
