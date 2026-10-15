//
//  ZheeAnalyzerHubView.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//

import SwiftUI

struct ZheeAnalyzerHubView: View {
    var body: some View {
        List {
            Section("Chọn loại phân tích") {
                NavigationLink(destination: ZheeIPAAnalyzerView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phân tích IPA")
                            Text("Link, secret, provisioning, Mach-O, framework — file iOS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                }
                NavigationLink(destination: ZheeAPKAnalyzerView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phân tích APK")
                            Text("Bóc tách gói Android ngay trên iPhone — không cần Android / PC")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "cube.box")
                    }
                }
                NavigationLink(destination: ZheeHexAnalyzerView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hex & Chuỗi")
                            Text("Xem hex, bóc chuỗi, quét link & secret — file bất kỳ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "textformat.123")
                    }
                }
            }
            Section {
                Text("Tất cả phân tích đều chạy offline trên máy, không gửi file đi đâu. Secret/key luôn bị che khi hiển thị.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Phân tích file")
        .navigationBarTitleDisplayMode(.inline)
    }
}
