//
//  ZheeSplashView.swift
//  ZheeSign
//
//  Màn hình chào: chữ Z hoạt hình tự vẽ nét + phát sáng.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

/// Chữ Z vẽ bằng Path để animate nét vẽ
struct AnimatedZShape: Shape {
	func path(in rect: CGRect) -> Path {
		var p = Path()
		let w = rect.width
		let h = rect.height
		// Nét ngang trên
		p.move(to: CGPoint(x: w * 0.15, y: h * 0.15))
		p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.15))
		// Nét chéo
		p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.85))
		// Nét ngang dưới
		p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))
		return p
	}
}

struct ZheeSplashView: View {
	@State private var drawProgress: CGFloat = 0
	@State private var glow: Double = 0.3
	@State private var textOpacity: Double = 0
	@State private var wiggle: Double = 0
	
	var body: some View {
		ZStack {
			Color(.systemBackground).ignoresSafeArea()
			
			VStack(spacing: 20) {
				ZStack {
					// Lớp phát sáng
					AnimatedZShape()
						.trim(from: 0, to: drawProgress)
						.stroke(
							LinearGradient(colors: [.cyan, .blue, .purple, .pink],
										   startPoint: .topLeading, endPoint: .bottomTrailing),
							style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round)
						)
						.frame(width: 110, height: 110)
						.shadow(color: .blue.opacity(glow), radius: 25)
						.shadow(color: .purple.opacity(glow * 0.8), radius: 50)
						.rotationEffect(.degrees(wiggle))
				}
				
				Text("ZheeSign")
					.font(.system(size: 30, weight: .bold, design: .rounded))
					.foregroundStyle(
						LinearGradient(colors: [.cyan, .blue, .purple, .pink],
									   startPoint: .leading, endPoint: .trailing)
					)
					.opacity(textOpacity)
			}
		}
		.onAppear {
			// Vẽ nét chữ Z trong 0.8s
			withAnimation(.easeInOut(duration: 0.8)) {
				drawProgress = 1
			}
			// Tên hiện sau
			withAnimation(.easeIn(duration: 0.4).delay(0.6)) {
				textOpacity = 1
			}
			// Phát sáng nhấp nháy
			withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
				glow = 0.9
			}
			// Lắc nhẹ cho vui
			withAnimation(.easeInOut(duration: 0.5).delay(0.8)) {
				wiggle = 4
			}
		}
	}
}
