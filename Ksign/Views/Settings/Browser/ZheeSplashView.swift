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
	@State private var rotate3D: Double = 0
	@State private var scale: CGFloat = 0.8
	@State private var floatY: CGFloat = 0
	@State private var particles: [Particle] = (0..<12).map { _ in Particle.random() }
	
	struct Particle: Identifiable {
		let id = UUID()
		var x: CGFloat
		var y: CGFloat
		var size: CGFloat
		var color: Color
		var speed: Double
		static func random() -> Particle {
			Particle(
				x: CGFloat.random(in: -120...120),
				y: CGFloat.random(in: -120...120),
				size: CGFloat.random(in: 3...8),
				color: [.cyan, .blue, .purple, .pink].randomElement()!,
				speed: Double.random(in: 1...2)
			)
		}
	}
	
	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			
			// Hạt 3D bay xung quanh
			ForEach(particles) { p in
				Circle()
					.fill(p.color)
					.frame(width: p.size, height: p.size)
					.offset(x: p.x, y: p.y + floatY)
					.blur(radius: 1)
					.opacity(0.7)
			}
			
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
						// 3D: xoay + scale + nổi
						.rotation3DEffect(.degrees(rotate3D), axis: (x: 0, y: 1, z: 0))
						.scaleEffect(scale)
						.offset(y: floatY)
				}
				
				Text("ZheeSign")
					.font(.system(size: 30, weight: .bold, design: .rounded))
					.foregroundStyle(
						LinearGradient(colors: [.cyan, .blue, .purple, .pink],
									   startPoint: .leading, endPoint: .trailing)
					)
					.opacity(textOpacity)
					.scaleEffect(scale)
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
			// 3D: xoay 360° + scale lên + nổi lên xuống
			withAnimation(.easeInOut(duration: 1.2).delay(0.5)) {
				rotate3D = 360
				scale = 1.0
			}
			withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(1.0)) {
				floatY = -8
			}
		}
	}
}
