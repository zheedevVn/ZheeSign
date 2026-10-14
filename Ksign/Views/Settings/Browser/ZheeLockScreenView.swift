//
//  ZheeLockScreenView.swift
//  ZheeSign
//
//  Màn hình khóa: Face ID + bàn phím PIN.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeLockScreenView: View {
	@ObservedObject var lock = ZheeAppLockManager.shared
	@State private var pin = ""
	@State private var shake = false
	@State private var error = false
	
	var body: some View {
		ZStack {
			// Nền
			LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
						   startPoint: .top, endPoint: .bottom)
				.ignoresSafeArea()
			
			VStack(spacing: 28) {
				Spacer()
				
				// Logo
				if let iconName = Bundle.main.iconFileName,
				   let icon = UIImage(named: iconName) {
					Image(uiImage: icon)
						.resizable()
						.frame(width: 76, height: 76)
						.clipShape(RoundedRectangle(cornerRadius: 18))
						.shadow(color: .accentColor.opacity(0.4), radius: 16)
				}
				
				VStack(spacing: 6) {
					Text("ZheeSign đã khóa")
						.font(.title2.bold())
					Text("Nhập mã PIN để mở khóa")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				
				// Chấm PIN
				HStack(spacing: 16) {
					ForEach(0..<6, id: \.self) { i in
						Circle()
							.fill(i < pin.count ? Color.accentColor : Color(.systemGray4))
							.frame(width: 14, height: 14)
					}
				}
				.offset(x: shake ? -10 : 0)
				
				if error {
					Text("Sai mã PIN, thử lại")
						.font(.caption)
						.foregroundColor(.red)
				}
				
				// Bàn phím số
				VStack(spacing: 14) {
					ForEach(0..<3) { row in
						HStack(spacing: 24) {
							ForEach(1...3, id: \.self) { col in
								numButton(row * 3 + col)
							}
						}
					}
					HStack(spacing: 24) {
						// Face ID
						if lock.useBiometrics && lock.canUseBiometrics {
							Button {
								unlockBiometric()
							} label: {
								Image(systemName: lock.biometricType == .faceID ? "faceid" : "touchid")
									.font(.title2)
									.foregroundColor(.accentColor)
									.frame(width: 72, height: 72)
									.background(Circle().fill(Color(.secondarySystemBackground)))
							}
						} else {
							Color.clear.frame(width: 72, height: 72)
						}
						numButton(0)
						Button {
							if !pin.isEmpty { pin.removeLast() }
						} label: {
							Image(systemName: "delete.left.fill")
								.font(.title2)
								.foregroundColor(.secondary)
								.frame(width: 72, height: 72)
						}
					}
				}
				
				Spacer()
			}
			.padding()
		}
		.onAppear {
			// Tắt bàn phím khi màn khóa hiện - tránh bàn phím đè lên màn khóa
			UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
			// Tự bật sinh trắc học khi mở màn khóa
			if lock.useBiometrics && lock.canUseBiometrics {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
					unlockBiometric()
				}
			}
		}
	}
	
	private func numButton(_ n: Int) -> some View {
		Button {
			guard pin.count < 6 else { return }
			pin.append("\(n)")
			if pin.count == 6 {
				checkPIN()
			}
		} label: {
			Text("\(n)")
				.font(.title)
				.foregroundColor(.primary)
				.frame(width: 72, height: 72)
				.background(Circle().fill(Color(.secondarySystemBackground)))
		}
	}
	
	private func checkPIN() {
		if lock.verifyPIN(pin) {
			error = false
			lock.unlock()
			pin = ""
		} else {
			error = true
			withAnimation(.default.repeatCount(3, autoreverses: true)) {
				shake.toggle()
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
				pin = ""
			}
		}
	}
	
	private func unlockBiometric() {
		lock.authenticateBiometric { success in
			if success { lock.unlock() }
		}
	}
}
