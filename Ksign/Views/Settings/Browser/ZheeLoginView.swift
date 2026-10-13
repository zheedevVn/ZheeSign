//
//  ZheeLoginView.swift
//  ZheeSign
//
//  Màn hình đăng nhập bằng Zhee — animation đẹp.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import WebKit

struct ZheeLoginView: View {
	@ObservedObject var auth = ZheeAuthManager.shared
	@State private var showWebLogin = false
	@State private var loginState = UUID().uuidString
	
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
			// Nền gradient động
			LinearGradient(
				colors: [Color(red: 0.08, green: 0.08, blue: 0.22), Color(red: 0.14, green: 0.04, blue: 0.28)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
			
			// Orbs trôi
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
				
				// Logo Z với glow pulse
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
				
				// Nút đăng nhập
				Button {
					loginState = UUID().uuidString
					showWebLogin = true
				} label: {
					HStack(spacing: 12) {
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
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.background(.white)
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
					.shadow(color: .purple.opacity(0.3), radius: 12)
				}
				.scaleEffect(buttonOpacity > 0 ? 1 : 0.9)
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
			// Staggered entrance
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
			// Orbs trôi liên tục
			withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
				orbOffset = 20
			}
			// Glow pulse
			withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
				glowPulse = true
			}
		}
		.fullScreenCover(isPresented: $showWebLogin) {
			ZheeOAuthWebView(state: loginState) {
				showWebLogin = false
			}
		}
	}
}

// MARK: - WebView cho OAuth (full screen, hỗ trợ popup)
private struct ZheeOAuthWebView: UIViewRepresentable {
	let state: String
	var onComplete: () -> Void
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	func makeUIView(context: Context) -> WKWebView {
		let config = WKWebViewConfiguration()
		config.preferences.javaScriptEnabled = true
		
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.navigationDelegate = context.coordinator
		webView.uiDelegate = context.coordinator
		webView.allowsBackForwardNavigationGestures = true
		
		// Nút đóng
		let closeButton = UIButton(type: .system)
		closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
		closeButton.tintColor = .systemGray
		closeButton.addTarget(context.coordinator, action: #selector(Coordinator.closeTapped), for: .touchUpInside)
		
		if let url = ZheeAuthManager.shared.authorizeURL(state: state) {
			webView.load(URLRequest(url: url))
		}
		return webView
	}
	
	func updateUIView(_ uiView: WKWebView, context: Context) {}
	
	class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
		var parent: ZheeOAuthWebView
		var popupWebView: WKWebView?
		
		init(_ parent: ZheeOAuthWebView) {
			self.parent = parent
		}
		
		@objc func closeTapped() {
			parent.onComplete()
		}
		
		// Chặn redirect để lấy code
		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
			if let url = navigationAction.request.url,
			   url.absoluteString.hasPrefix("https://api-zhee.vercel.app/oauth/mobile-callback") {
				decisionHandler(.cancel)
				ZheeAuthManager.shared.handleCallback(url: url) { _ in
					DispatchQueue.main.async {
						self.parent.onComplete()
					}
				}
				return
			}
			decisionHandler(.allow)
		}
		
		// Hỗ trợ popup (Google login mở cửa sổ mới)
		func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
			if navigationAction.targetFrame == nil {
				let popup = WKWebView(frame: webView.bounds, configuration: configuration)
				popup.navigationDelegate = self
				popup.uiDelegate = self
				popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				webView.addSubview(popup)
				popupWebView = popup
				return popup
			}
			return nil
		}
		
		func webViewDidClose(_ webView: WKWebView) {
			webView.removeFromSuperview()
			if webView == popupWebView {
				popupWebView = nil
			}
		}
	}
}
