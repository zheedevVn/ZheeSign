//
//  ZheeLoginView.swift
//  ZheeSign
//
//  Màn hình đăng nhập bằng Zhee — animation đẹp, chia sẻ cookie Safari.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import AuthenticationServices

struct ZheeLoginView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var loginState = UUID().uuidString
	@State private var isAuthenticating = false
	
	// Animation states
	@State private var logoScale: CGFloat = 0.5
	@State private var logoOpacity: Double = 0
	@State private var titleOffset: CGFloat = 30
	@State private var titleOpacity: Double = 0
	@State private var buttonOffset: CGFloat = 50
	@State private var buttonOpacity: Double = 0
	@State private var orbOffset: CGFloat = 0
	@State private var glowPulse = false
	
	var body: some View {
		ZStack {
			LinearGradient(
				colors: [Color(red: 0.08, green: 0.08, blue: 0.22), Color(red: 0.14, green: 0.04, blue: 0.28)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
			
			Circle()
				.fill(Color.purple.opacity(0.35))
				.frame(width: 220, height: 220)
				.blur(radius: 70)
				.offset(x: -90 + orbOffset, y: -160 - orbOffset * 0.5)
			Circle()
				.fill(Color.cyan.opacity(0.28))
				.frame(width: 190, height: 190)
				.blur(radius: 70)
				.offset(x: 110 - orbOffset, y: 190 + orbOffset * 0.4)
			Circle()
				.fill(Color.pink.opacity(0.2))
				.frame(width: 140, height: 140)
				.blur(radius: 60)
				.offset(x: -40, y: 60 + orbOffset * 0.6)
			
			VStack(spacing: 24) {
				Spacer()
				
				ZStack {
					RoundedRectangle(cornerRadius: 30, style: .continuous)
						.fill(
							LinearGradient(
								colors: [.cyan, .purple, .pink],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 110, height: 110)
						.shadow(color: .purple.opacity(glowPulse ? 0.8 : 0.4), radius: glowPulse ? 30 : 15)
						.scaleEffect(glowPulse ? 1.05 : 1.0)
					
					Text("Z")
						.font(.system(size: 62, weight: .black))
						.foregroundColor(.white)
						.shadow(radius: 5)
				}
				.scaleEffect(logoScale)
				.opacity(logoOpacity)
				
				VStack(spacing: 10) {
					Text("Chào mừng đến ZheeSign")
						.font(.title)
						.bold()
						.foregroundColor(.white)
					
					Text("Đăng nhập để sử dụng ứng dụng\nvà đồng bộ tài khoản của bạn")
						.multilineTextAlignment(.center)
						.foregroundColor(.white.opacity(0.7))
						.font(.subheadline)
				}
				.offset(y: titleOffset)
				.opacity(titleOpacity)
				
				Spacer()
				
				Button {
					startOAuth()
				} label: {
					HStack(spacing: 12) {
						if isAuthenticating {
							ProgressView()
								.tint(.primary)
						} else {
							ZStack {
								RoundedRectangle(cornerRadius: 8, style: .continuous)
									.fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
									.frame(width: 28, height: 28)
								Text("Z")
									.font(.system(size: 16, weight: .black))
									.foregroundColor(.white)
							}
							Text("Đăng nhập bằng Zhee")
								.font(.headline)
								.foregroundColor(.primary)
						}
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.background(.white)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
					.shadow(color: .purple.opacity(0.3), radius: 12)
				}
				.disabled(isAuthenticating)
				.offset(y: buttonOffset)
				.opacity(buttonOpacity)
				.padding(.horizontal, 32)
				
				Text("Chưa có tài khoản? Đăng ký ngay trong\nmàn hình tiếp theo — miễn phí.")
					.multilineTextAlignment(.center)
					.font(.caption)
					.foregroundColor(.white.opacity(0.6))
					.opacity(buttonOpacity)
				
				Spacer()
					.frame(height: 40)
			}
		}
		.onAppear {
			withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
				logoScale = 1.0
				logoOpacity = 1.0
			}
			withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
				titleOffset = 0
				titleOpacity = 1.0
			}
			withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
				buttonOffset = 0
				buttonOpacity = 1.0
			}
			withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
				orbOffset = 20
			}
			withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
				glowPulse = true
			}
		}
	}
	
	private func startOAuth() {
		guard let authURL = auth.authorizeURL(state: loginState) else { return }
		isAuthenticating = true
		
		let session = ASWebAuthenticationSession(
			url: authURL,
			callbackURLScheme: "zheesign"
		) { callbackURL, error in
			DispatchQueue.main.async {
				self.isAuthenticating = false
				if let url = callbackURL {
					self.auth.handleCallback(url: url) { _ in }
				}
			}
		}
		session.presentationContextProvider = AuthPresentationProvider.shared
		// Chia sẻ cookie với Safari — không phải đăng nhập Google lại
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
