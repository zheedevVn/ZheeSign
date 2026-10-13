//
//  ZheeLoginView.swift
//  ZheeSign
//
//  Màn hình đăng nhập bằng Zhee — đẹp, có đăng ký ngay trong web.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import AuthenticationServices

struct ZheeLoginView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var loginState = UUID().uuidString
	@State private var isAuthenticating = false
	
	var body: some View {
		ZStack {
			// Nền gradient
			LinearGradient(
				colors: [Color(red: 0.1, green: 0.1, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.3)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
			
			// Orbs trang trí
			Circle()
				.fill(Color.purple.opacity(0.3))
				.frame(width: 200, height: 200)
				.blur(radius: 60)
				.offset(x: -80, y: -150)
			Circle()
				.fill(Color.cyan.opacity(0.25))
				.frame(width: 180, height: 180)
				.blur(radius: 60)
				.offset(x: 100, y: 180)
			
			VStack(spacing: 24) {
				Spacer()
				
				// Logo Z
				ZStack {
					RoundedRectangle(cornerRadius: 28, style: .continuous)
						.fill(
							LinearGradient(
								colors: [.cyan, .purple, .pink],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 100, height: 100)
						.shadow(color: .purple.opacity(0.5), radius: 20)
					
					Text("Z")
						.font(.system(size: 56, weight: .black))
						.foregroundColor(.white)
				}
				
				VStack(spacing: 8) {
					Text("Chào mừng đến ZheeSign")
						.font(.title)
						.bold()
						.foregroundColor(.white)
					
					Text("Đăng nhập để sử dụng ứng dụng\nvà đồng bộ tài khoản của bạn")
						.multilineTextAlignment(.center)
						.foregroundColor(.white.opacity(0.7))
						.font(.subheadline)
				}
				
				Spacer()
				
				// Nút đăng nhập
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
					.shadow(color: .black.opacity(0.2), radius: 10)
				}
				.disabled(isAuthenticating)
				.padding(.horizontal, 32)
				
				Text("Chưa có tài khoản? Đăng ký ngay trong\nmàn hình tiếp theo — miễn phí.")
					.multilineTextAlignment(.center)
					.font(.caption)
					.foregroundColor(.white.opacity(0.6))
				
				Spacer()
					.frame(height: 40)
			}
		}
	}
	
	private func startOAuth() {
		guard let authURL = auth.authorizeURL(state: loginState) else { return }
		isAuthenticating = true
		
		let session = ASWebAuthenticationSession(
			url: authURL,
			callbackURLScheme: "https"
		) { callbackURL, error in
			DispatchQueue.main.async {
				self.isAuthenticating = false
				if let url = callbackURL,
				   url.absoluteString.hasPrefix(ZheeAuthManager.redirectURI) {
					self.auth.handleCallback(url: url) { _ in }
				}
			}
		}
		session.presentationContextProvider = AuthPresentationProvider.shared
		session.prefersEphemeralWebBrowserSession = false
		session.start()
	}
}

// MARK: - Presentation provider
private class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
	static let shared = AuthPresentationProvider()
	
	func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap { $0.windows }
			.first { $0.isKeyWindow } ?? ASPresentationAnchor()
	}
}
