//
//  ZheeLoginView.swift
//  ZheeSign
//
//  Màn hình đăng nhập bằng Zhee — animation cao cấp.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import AuthenticationServices

struct ZheeLoginView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var loginState = UUID().uuidString
	@State private var isAuthenticating = false
	
	@State private var logoScale: CGFloat = 0.3
	@State private var logoOpacity: Double = 0
	@State private var logoRotation: Double = -15
	@State private var titleOffset: CGFloat = 40
	@State private var titleOpacity: Double = 0
	@State private var buttonOffset: CGFloat = 60
	@State private var buttonOpacity: Double = 0
	@State private var orb1 = CGSize.zero
	@State private var orb2 = CGSize.zero
	@State private var orb3 = CGSize.zero
	@State private var glowPulse = false
	@State private var shimmer = false
	@State private var titleGradientShift = false
	
	var body: some View {
		ZStack {
			// Nền gradient sâu
			LinearGradient(
				colors: [
					Color(red: 0.06, green: 0.06, blue: 0.18),
					Color(red: 0.12, green: 0.03, blue: 0.25),
					Color(red: 0.05, green: 0.08, blue: 0.2)
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
			
			// Orbs trôi đa hướng
			Circle()
				.fill(Color.purple.opacity(0.4))
				.frame(width: 240, height: 240)
				.blur(radius: 80)
				.offset(x: -100 + orb1.width, y: -170 + orb1.height)
			Circle()
				.fill(Color.cyan.opacity(0.3))
				.frame(width: 200, height: 200)
				.blur(radius: 80)
				.offset(x: 120 + orb2.width, y: 200 + orb2.height)
			Circle()
				.fill(Color.pink.opacity(0.25))
				.frame(width: 150, height: 150)
				.blur(radius: 70)
				.offset(x: -50 + orb3.width, y: 80 + orb3.height)
			
			// Hạt sao lấp lánh
			ForEach(0..<12, id: \.self) { i in
				Circle()
					.fill(Color.white.opacity(0.6))
					.frame(width: 3, height: 3)
					.position(
						x: CGFloat(40 + (i * 67) % 320),
						y: CGFloat(80 + (i * 113) % 600)
					)
					.opacity(glowPulse ? 0.9 : 0.2)
			}
			
			VStack(spacing: 26) {
				Spacer()
				
				// Logo Z — xoay vào + glow
				ZStack {
					RoundedRectangle(cornerRadius: 32, style: .continuous)
						.fill(
							AngularGradient(
								colors: [.cyan, .purple, .pink, .cyan],
								center: .center
							)
						)
						.frame(width: 120, height: 120)
						.shadow(color: .purple.opacity(glowPulse ? 0.9 : 0.4), radius: glowPulse ? 35 : 18)
						.scaleEffect(glowPulse ? 1.04 : 1.0)
					
					Text("Z")
						.font(.system(size: 68, weight: .black))
						.foregroundColor(.white)
						.shadow(color: .black.opacity(0.3), radius: 5)
				}
				.scaleEffect(logoScale)
				.opacity(logoOpacity)
				.rotationEffect(.degrees(logoRotation))
				
				VStack(spacing: 12) {
					// Tiêu đề gradient chuyển màu
					Text("Chào mừng đến ZheeSign")
						.font(.system(size: 30, weight: .bold))
						.foregroundStyle(
							LinearGradient(
								colors: titleGradientShift ? [.cyan, .purple, .pink] : [.pink, .cyan, .purple],
								startPoint: .leading,
								endPoint: .trailing
							)
						)
					
					Text("Đăng nhập để mở khóa toàn bộ tính năng\nvà đồng bộ tài khoản của bạn")
						.multilineTextAlignment(.center)
						.foregroundColor(.white.opacity(0.65))
						.font(.subheadline)
				}
				.offset(y: titleOffset)
				.opacity(titleOpacity)
				
				Spacer()
				
				// Nút đăng nhập — shimmer
				Button {
					startOAuth()
				} label: {
					ZStack {
						HStack(spacing: 12) {
							if isAuthenticating {
								ProgressView()
									.tint(.primary)
							} else {
								ZStack {
									RoundedRectangle(cornerRadius: 9, style: .continuous)
										.fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
										.frame(width: 30, height: 30)
									Text("Z")
										.font(.system(size: 17, weight: .black))
										.foregroundColor(.white)
								}
								Text("Đăng nhập bằng Zhee")
									.font(.headline)
									.foregroundColor(.primary)
							}
						}
						
						// Shimmer sweep
						LinearGradient(
							colors: [.clear, .white.opacity(0.5), .clear],
							startPoint: .leading,
							endPoint: .trailing
						)
						.frame(width: 80)
						.offset(x: shimmer ? 200 : -200)
						.blur(radius: 2)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 17)
					.background(.white)
					.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
					.shadow(color: .purple.opacity(0.4), radius: 15)
				}
				.disabled(isAuthenticating)
				.scaleEffect(buttonOpacity > 0 ? 1 : 0.92)
				.offset(y: buttonOffset)
				.opacity(buttonOpacity)
				.padding(.horizontal, 36)
				
				Text("Chưa có tài khoản? Đăng ký miễn phí\nngay trong màn hình tiếp theo.")
					.multilineTextAlignment(.center)
					.font(.caption)
					.foregroundColor(.white.opacity(0.55))
					.opacity(buttonOpacity)
				
				Spacer()
					.frame(height: 44)
			}
		}
		.onAppear { startAnimations() }
	}
	
	private func startAnimations() {
		withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
			logoScale = 1.0; logoOpacity = 1.0; logoRotation = 0
		}
		withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
			titleOffset = 0; titleOpacity = 1.0
		}
		withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.55)) {
			buttonOffset = 0; buttonOpacity = 1.0
		}
		withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
			orb1 = CGSize(width: 30, height: 25)
		}
		withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
			orb2 = CGSize(width: -35, height: -20)
		}
		withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
			orb3 = CGSize(width: 25, height: -30)
		}
		withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
			glowPulse = true
		}
		withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
			shimmer = true
		}
		withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
			titleGradientShift = true
		}
	}
	
	private func startOAuth() {
		guard let authURL = auth.authorizeURL(state: loginState) else { return }
		isAuthenticating = true
		let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "zheesign") { callbackURL, _ in
			DispatchQueue.main.async {
				self.isAuthenticating = false
				if let url = callbackURL { self.auth.handleCallback(url: url) { _ in } }
			}
		}
		session.presentationContextProvider = AuthPresentationProvider.shared
		session.prefersEphemeralWebBrowserSession = false
		session.start()
	}
}

private class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
	static let shared = AuthPresentationProvider()
	func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap { $0.windows }
			.first { $0.isKeyWindow } ?? ASPresentationAnchor()
	}
}
