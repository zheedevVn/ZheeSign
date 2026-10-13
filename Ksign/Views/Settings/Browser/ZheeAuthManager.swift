//
//  ZheeAuthManager.swift
//  ZheeSign
//
//  Đăng nhập bằng Zhee (OAuth) — lưu session 30 ngày.
//  © 2026 Hồ Đức Minh
//

import Foundation
import SwiftUI
import Combine

class ZheeAuthManager: ObservableObject {
	static let shared = ZheeAuthManager()
	
	// TODO: Thay bằng client_id thật từ api-zhee.vercel.app/ho-so
	static let clientId = "zhc_cec13d08004acae37560776b"
	static let redirectURI = "https://api-zhee.vercel.app/oauth/mobile-callback"
	static let authorizeURL = "https://api-zhee.vercel.app/oauth/authorize"
	static let tokenURL = "https://api-zhee.vercel.app/oauth/token"
	static let userinfoURL = "https://api-zhee.vercel.app/oauth/userinfo"
	
	private let tokenKey = "zhee_access_token"
	private let expiryKey = "zhee_token_expiry"
	private let userKey = "zhee_user_info"
	
	@Published var isLoggedIn: Bool = false
	@Published var userInfo: [String: Any]? = nil
	@Published var isLoading: Bool = false
	
	private init() {
		checkSession()
	}
	
	// MARK: - Session (30 ngày)
	
	var isSessionValid: Bool {
		guard let token = UserDefaults.standard.string(forKey: tokenKey),
			  !token.isEmpty,
			  let expiry = UserDefaults.standard.object(forKey: expiryKey) as? Date else {
			return false
		}
		return Date() < expiry
	}
	
	func checkSession() {
		if isSessionValid {
			isLoggedIn = true
			if let data = UserDefaults.standard.data(forKey: userKey),
			   let user = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
				userInfo = user
			}
		} else {
			logout(silent: true)
		}
	}
	
	private func saveSession(token: String, user: [String: Any]?) {
		UserDefaults.standard.set(token, forKey: tokenKey)
		// Lưu 30 ngày
		UserDefaults.standard.set(Date().addingTimeInterval(30 * 24 * 3600), forKey: expiryKey)
		if let user = user,
		   let data = try? JSONSerialization.data(withJSONObject: user) {
			UserDefaults.standard.set(data, forKey: userKey)
			userInfo = user
		}
		isLoggedIn = true
	}
	
	func logout(silent: Bool = false) {
		UserDefaults.standard.removeObject(forKey: tokenKey)
		UserDefaults.standard.removeObject(forKey: expiryKey)
		UserDefaults.standard.removeObject(forKey: userKey)
		userInfo = nil
		isLoggedIn = false
	}
	
	var accessToken: String? {
		guard isSessionValid else { return nil }
		return UserDefaults.standard.string(forKey: tokenKey)
	}
	
	// MARK: - OAuth Flow
	
	func authorizeURL(state: String) -> URL? {
		var comps = URLComponents(string: Self.authorizeURL)
		comps?.queryItems = [
			URLQueryItem(name: "client_id", value: Self.clientId),
			URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "scope", value: "openid profile"),
			URLQueryItem(name: "state", value: state),
		]
		return comps?.url
	}
	
	func handleCallback(url: URL, completion: @escaping (Bool) -> Void) {
		guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
			  let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
			completion(false)
			return
		}
		
		isLoading = true
		exchangeCode(code: code) { [weak self] success in
			DispatchQueue.main.async {
				self?.isLoading = false
				completion(success)
			}
		}
	}
	
	private func exchangeCode(code: String, completion: @escaping (Bool) -> Void) {
		guard let url = URL(string: Self.tokenURL) else {
			completion(false)
			return
		}
		
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(Self.redirectURI)&client_id=\(Self.clientId)&client_secret=zhs_ac4dac86d909ac485cff28fa4cdb4e4afd0fe9e855cbbfab04230ebc61c48bcc"
		req.httpBody = body.data(using: .utf8)
		
		URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
			guard let data = data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				  let token = json["access_token"] as? String else {
				completion(false)
				return
			}
			self?.fetchUserInfo(token: token) { user in
				self?.saveSession(token: token, user: user)
				completion(true)
			}
		}.resume()
	}
	
	private func fetchUserInfo(token: String, completion: @escaping ([String: Any]?) -> Void) {
		guard let url = URL(string: Self.userinfoURL) else {
			completion(nil)
			return
		}
		var req = URLRequest(url: url)
		req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		URLSession.shared.dataTask(with: req) { data, _, _ in
			guard let data = data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
				completion(nil)
				return
			}
			completion(json)
		}.resume()
	}
	
	var displayName: String {
		if let user = userInfo {
			return (user["name"] as? String) ?? (user["email"] as? String) ?? "Người dùng Zhee"
		}
		return "Người dùng Zhee"
	}
	
	var avatarURL: URL? {
		if let user = userInfo, let avatar = user["picture"] as? String {
			return URL(string: avatar)
		}
		return nil
	}
}
