//
//  AboutNyaView.swift
//  Ksign
//
//  Created by Nagata Asami on 23/5/25.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - View
struct AboutNyaView: View {
	private let _dataService = NBFetchService()
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
            Section {
                VStack {
                    Image(uiImage: (UIImage(named: Bundle.main.iconFileName ?? ""))! )
                        .appIconStyle(size: 72)

                    Text(Bundle.main.exec)
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.accent)

                    Text("Hồ Đức Minh")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(.localized("Version"))
                        Text(Bundle.main.version)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(EmptyView())

            NBSection("ZheeSign") {
                _credit(name: "Hồ Đức Minh", desc: "Developer", github: "zheedevVn")
            }

            NBSection(.localized("License")) {
                Text("ZheeSign is free software under GNU GPL-3.0. Based on Ksign by vulnnull, Nyasami/Ksign and Feather by khcrysalis.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                _credit(name: "vulnnull", desc: "Ksign", github: "vulnnull")
                _credit(name: "Nyasami", desc: "Ksign", github: "Nyasami")
                _credit(name: "khcrysalis", desc: "Feather", github: "khcrysalis")
            } footer: {
                Text(Bundle.main.bundleIdentifier ?? "")
            }
		}
	}
	
}

// MARK: - Extension: view
extension AboutNyaView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		FRIconCellView(
			title: name ?? github,
			subtitle: desc ?? "",
			iconUrl: URL(string: "https://github.com/\(github).png")!,
			trailing: AnyView(
				Image(systemName: "arrow.up.right")
					.foregroundStyle(.secondary)
			)
		)
		.onTapGesture {
			if let url = URL(string: "https://github.com/\(github)") {
				UIApplication.shared.open(url)
			}
		}
	}
}
