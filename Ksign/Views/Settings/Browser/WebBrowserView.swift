//
//  WebBrowserView.swift
//  ZheeSign
//
//  Trình duyệt web trong ứng dụng — nhập URL bất kỳ để mở.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import WebKit

struct WebBrowserView: View {
	@State private var urlString: String = "https://"
	@State private var currentURL: URL? = nil
	@State private var canGoBack = false
	@State private var canGoForward = false
	@State private var isLoading = false
	@State private var showAlert = false
	@FocusState private var urlFieldFocused: Bool
	
	var body: some View {
		VStack(spacing: 0) {
			// Thanh địa chỉ
			HStack(spacing: 8) {
				Button(action: goBack) {
					Image(systemName: "chevron.left")
				}
				.disabled(!canGoBack)
				
				Button(action: goForward) {
					Image(systemName: "chevron.right")
				}
				.disabled(!canGoForward)
				
				TextField("Nhập link hoặc URL...", text: $urlString)
					.textFieldStyle(.roundedBorder)
					.keyboardType(.URL)
					.autocapitalization(.none)
					.disableAutocorrection(true)
					.focused($urlFieldFocused)
					.onSubmit { loadURL() }
				
				if isLoading {
					ProgressView()
						.frame(width: 20, height: 20)
				} else {
					Button(action: reload) {
						Image(systemName: "arrow.clockwise")
					}
				}
				
				Button("Mở") {
					urlFieldFocused = false
					loadURL()
				}
				.buttonStyle(.borderedProminent)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(.bar)
			
			Divider()
			
			// Nội dung web
			if let url = currentURL {
				BrowserWebView(
					url: url,
					canGoBack: $canGoBack,
					canGoForward: $canGoForward,
					isLoading: $isLoading,
					onNavigate: { newURL in
						urlString = newURL.absoluteString
					}
				)
				.ignoresSafeArea(.container, edges: .bottom)
			} else {
				// Màn hình chào
				VStack(spacing: 16) {
					Spacer()
					Image(systemName: "globe")
						.font(.system(size: 64))
						.foregroundStyle(.tint)
					Text("Trình duyệt web")
						.font(.title2)
						.bold()
					Text("Nhập link hoặc URL bất kỳ ở thanh trên\nđể mở trực tiếp trong ứng dụng.")
						.multilineTextAlignment(.center)
						.foregroundStyle(.secondary)
					
					// Gợi ý nhanh
					VStack(spacing: 8) {
						ForEach([
							("GitHub ZheeSign", "https://github.com/zheedevVn/ZheeSign"),
							("Kênh Telegram", "https://t.me/zheevipv1"),
						], id: \.1) { name, link in
							Button {
								urlString = link
								loadURL()
							} label: {
								HStack {
									Image(systemName: "link")
									Text(name)
									Spacer()
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.padding(.horizontal, 16)
								.padding(.vertical, 10)
								.background(Color(.secondarySystemBackground))
								.clipShape(RoundedRectangle(cornerRadius: 10))
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.horizontal, 32)
					Spacer()
				}
			}
		}
		.navigationTitle("Trình duyệt")
		.navigationBarTitleDisplayMode(.inline)
		.alert("URL không hợp lệ", isPresented: $showAlert) {
			Button("OK", role: .cancel) { }
		}
	}
	
	private func normalizedURL(from input: String) -> URL? {
		var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty else { return nil }
		if !text.contains("://") {
			text = "https://" + text
		}
		return URL(string: text)
	}
	
	private func loadURL() {
		guard let url = normalizedURL(from: urlString) else {
			showAlert = true
			return
		}
		urlString = url.absoluteString
		currentURL = url
	}
	
	private func goBack() { BrowserWebView.goBack() }
	private func goForward() { BrowserWebView.goForward() }
	private func reload() { BrowserWebView.reload() }
}

// MARK: - WKWebView wrapper
private struct BrowserWebView: UIViewRepresentable {
	let url: URL
	@Binding var canGoBack: Bool
	@Binding var canGoForward: Bool
	@Binding var isLoading: Bool
	var onNavigate: (URL) -> Void
	
	private static weak var currentWebView: WKWebView?
	
	static func goBack() { currentWebView?.goBack() }
	static func goForward() { currentWebView?.goForward() }
	static func reload() { currentWebView?.reload() }
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	func makeUIView(context: Context) -> WKWebView {
		let webView = WKWebView()
		webView.navigationDelegate = context.coordinator
		webView.allowsBackForwardNavigationGestures = true
		Self.currentWebView = webView
		webView.load(URLRequest(url: url))
		return webView
	}
	
	func updateUIView(_ uiView: WKWebView, context: Context) {
		// Chỉ load khi URL khác với trang hiện tại
		if uiView.url != url {
			uiView.load(URLRequest(url: url))
		}
		Self.currentWebView = uiView
	}
	
	class Coordinator: NSObject, WKNavigationDelegate {
		var parent: BrowserWebView
		
		init(_ parent: BrowserWebView) {
			self.parent = parent
		}
		
		func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
			DispatchQueue.main.async {
				self.parent.isLoading = true
			}
		}
		
		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			DispatchQueue.main.async {
				self.parent.isLoading = false
				self.parent.canGoBack = webView.canGoBack
				self.parent.canGoForward = webView.canGoForward
				if let url = webView.url {
					self.parent.onNavigate(url)
				}
			}
		}
		
		func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
			DispatchQueue.main.async {
				self.parent.isLoading = false
			}
		}
	}
}
