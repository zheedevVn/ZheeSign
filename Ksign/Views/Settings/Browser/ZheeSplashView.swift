//
//  ZheeSplashView.swift
//  ZheeSign
//
//  Màn hình chào với hiệu ứng logo phát sáng khi mở app.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeSplashView: View {
	@State private var scale: CGFloat = 0.6
	@State private var opacity: Double = 0
	@State private var glow: Double = 0.3
	
	var body: some View {
		ZStack {
			Color(.systemBackground).ignoresSafeArea()
			
			VStack(spacing: 24) {
				if let iconName = Bundle.main.iconFileName,
				   let icon = UIImage(named: iconName) {
					Image(uiImage: icon)
						.resizable()
						.frame(width: 120, height: 120)
						.clipShape(RoundedRectangle(cornerRadius: 28))
						.scaleEffect(scale)
						.opacity(opacity)
						.shadow(color: .accentColor.opacity(glow), radius: 30)
						.shadow(color: .purple.opacity(glow * 0.7), radius: 60)
				}
				
				Text("ZheeSign")
					.font(.system(size: 28, weight: .bold))
					.foregroundStyle(
						LinearGradient(colors: [.accentColor, .purple], startPoint: .leading, endPoint: .trailing)
					)
					.opacity(opacity)
			}
		}
		.onAppear {
			withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
				scale = 1
				opacity = 1
			}
			withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
				glow = 0.8
			}
		}
	}
}
