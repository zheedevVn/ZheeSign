//
//  ZheeAppLockSettingsView.swift
//  ZheeSign
//
//  Cài đặt khóa ứng dụng.
//  © 2026 Hồ Đức Minh
//

import SwiftUI

struct ZheeAppLockSettingsView: View {
	@ObservedObject var lock = ZheeAppLockManager.shared
	@State private var showSetPIN = false
	@State private var delaySelection: Int = 0
	
	let delays: [(String, TimeInterval)] = [
		("Ngay lập tức", 0),
		("1 phút", 60),
		("5 phút", 300),
		("15 phút", 900),
		("1 giờ", 3600),
	]
	
	var body: some View {
		Form {
			Section {
				Toggle("Khóa ứng dụng", isOn: Binding(
					get: { lock.isEnabled },
					set: { lock.isEnabled = $0; if $0 && !lock.hasPIN { showSetPIN = true } }
				))
			} footer: {
				Text("Yêu cầu Face ID / mã PIN mỗi khi mở app.")
			}
			
			if lock.isEnabled {
				Section("Phương thức mở khóa") {
					if lock.canUseBiometrics {
						Toggle(lock.biometricName, isOn: Binding(
							get: { lock.useBiometrics },
							set: { lock.useBiometrics = $0 }
						))
					}
					
					Button(lock.hasPIN ? "Đổi mã PIN" : "Đặt mã PIN") {
						showSetPIN = true
					}
				}
				
				Section("Tự động khóa sau") {
					Picker("Thời gian", selection: $delaySelection) {
						ForEach(0..<delays.count, id: \.self) { i in
							Text(delays[i].0).tag(i)
						}
					}
					.onChange(of: delaySelection) { i in
						lock.lockDelay = delays[i].1
					}
				} footer: {
					Text("App sẽ tự khóa sau khoảng thời gian không dùng.")
				}
				
				Section {
					Button("Khóa ngay bây giờ") {
						lock.lock()
					}
				}
			}
		}
		.navigationTitle("Khóa ứng dụng")
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			if let idx = delays.firstIndex(where: { $0.1 == lock.lockDelay }) {
				delaySelection = idx
			}
		}
		.sheet(isPresented: $showSetPIN) {
			ZheeSetPINView()
		}
	}
}

// MARK: - Đặt mã PIN
struct ZheeSetPINView: View {
	@ObservedObject var lock = ZheeAppLockManager.shared
	@Environment(\.dismiss) var dismiss
	@State private var pin = ""
	@State private var confirmPin = ""
	@State private var step = 1
	@State private var error = ""
	
	var body: some View {
		NavigationView {
			VStack(spacing: 24) {
				Spacer()
				
				Text(step == 1 ? "Đặt mã PIN mới" : "Nhập lại để xác nhận")
					.font(.title2.bold())
				
				HStack(spacing: 16) {
					ForEach(0..<6, id: \.self) { i in
						Circle()
							.fill(i < (step == 1 ? pin : confirmPin).count ? Color.accentColor : Color(.systemGray4))
							.frame(width: 14, height: 14)
					}
				}
				
				if !error.isEmpty {
					Text(error).font(.caption).foregroundColor(.red)
				}
				
				VStack(spacing: 14) {
					ForEach(0..<3) { row in
						HStack(spacing: 24) {
							ForEach(1...3, id: \.self) { col in
								numButton(row * 3 + col)
							}
						}
					}
					HStack(spacing: 24) {
						Color.clear.frame(width: 72, height: 72)
						numButton(0)
						Button {
							if step == 1, !pin.isEmpty { pin.removeLast() }
							else if !confirmPin.isEmpty { confirmPin.removeLast() }
						} label: {
							Image(systemName: "delete.left.fill")
								.font(.title2).foregroundColor(.secondary)
								.frame(width: 72, height: 72)
						}
					}
				}
				
				Spacer()
			}
			.padding()
			.navigationTitle("Mã PIN")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("Hủy") { dismiss() }
				}
			}
		}
	}
	
	private func numButton(_ n: Int) -> some View {
		Button {
			if step == 1 {
				guard pin.count < 6 else { return }
				pin.append("\(n)")
				if pin.count == 6 { step = 2 }
			} else {
				guard confirmPin.count < 6 else { return }
				confirmPin.append("\(n)")
				if confirmPin.count == 6 { finish() }
			}
		} label: {
			Text("\(n)").font(.title).foregroundColor(.primary)
				.frame(width: 72, height: 72)
				.background(Circle().fill(Color(.secondarySystemBackground)))
		}
	}
	
	private func finish() {
		if pin == confirmPin {
			lock.setPIN(pin)
			lock.isEnabled = true
			dismiss()
		} else {
			error = "Mã PIN không khớp, thử lại"
			pin = ""
			confirmPin = ""
			step = 1
		}
	}
}
