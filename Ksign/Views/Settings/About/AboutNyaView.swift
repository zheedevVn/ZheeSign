//
//  AboutNyaView.swift
//  ZheeSign
//
//  © 2026 Hồ Đức Minh
//

import SwiftUI

// MARK: - View
struct AboutNyaView: View {
	@State private var animate = false
	
	var body: some View {
		ScrollView {
			VStack(spacing: 24) {
				// ===== HERO =====
				VStack(spacing: 14) {
					ZStack {
						// Glow nền
						Circle()
							.fill(
								LinearGradient(
									colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.2)],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.frame(width: 130, height: 130)
							.blur(radius: 30)
							.scaleEffect(animate ? 1.15 : 1.0)
						
						if let iconName = Bundle.main.iconFileName,
						   let icon = UIImage(named: iconName) {
							Image(uiImage: icon)
								.resizable()
								.frame(width: 96, height: 96)
								.clipShape(RoundedRectangle(cornerRadius: 22))
								.shadow(color: .accentColor.opacity(0.4), radius: 16)
								.offset(y: animate ? -4 : 4)
						}
					}
					.padding(.top, 20)
					
					Text("ZheeSign")
						.font(.system(size: 38, weight: .black))
						.foregroundStyle(
							LinearGradient(
								colors: animate ? [Color.accentColor, .blue] : [.blue, Color.accentColor],
								startPoint: .leading,
								endPoint: .trailing
							)
						)
					
					Text("v\(Bundle.main.version)")
						.font(.caption.bold())
						.foregroundColor(.white)
						.padding(.horizontal, 14)
						.padding(.vertical, 5)
						.background(
							Capsule()
								.fill(Color.accentColor)
						)
					
					Text("Công cụ ký và cài đặt IPA cho iOS\nNhanh • Đẹp • Miễn phí")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
				}
				
				// ===== DEVELOPER CARD =====
				VStack(spacing: 16) {
					HStack(spacing: 14) {
						AsyncImage(url: URL(string: "https://github.com/zheedevVn.png")) { phase in
							if let image = phase.image {
								image.resizable()
							} else {
								Circle()
									.fill(Color.accentColor.gradient)
									.overlay(
										Text("M")
											.font(.title.bold())
											.foregroundColor(.white)
									)
							}
						}
						.frame(width: 64, height: 64)
						.clipShape(Circle())
						.shadow(color: .accentColor.opacity(0.3), radius: 8)
						
						VStack(alignment: .leading, spacing: 4) {
							Text("Hồ Đức Minh")
								.font(.title3.bold())
							Text("Developer & Founder")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("@zheedevVn")
								.font(.caption)
								.foregroundColor(.accentColor)
						}
						
						Spacer()
					}
					
					Text("Đam mê tạo ra những công cụ iOS đẹp và tiện lợi cho cộng đồng Việt Nam. Tác giả của ZheeSign và nền tảng API Zhee.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, alignment: .leading)
					
					// Nút liên hệ
					HStack(spacing: 12) {
						LinkButton(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub", colors: [Color.accentColor, .blue]) {
							openURL("https://github.com/zheedevVn")
						}
						LinkButton(icon: "paperplane.fill", title: "Telegram", colors: [Color.accentColor, .blue]) {
							openURL("https://t.me/zheevipv1")
						}
					}
				}
				.padding(18)
				.background(
					RoundedRectangle(cornerRadius: 20)
						.fill(Color(.secondarySystemBackground))
						.overlay(
							RoundedRectangle(cornerRadius: 20)
								.stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
						)
				)
				.padding(.horizontal, 16)
				
				// ===== GIẤY PHÉP =====
				VStack(alignment: .leading, spacing: 12) {
					Text("Giấy phép")
						.font(.title2.bold())
						.padding(.horizontal, 16)
					
					VStack(alignment: .leading, spacing: 12) {
						Text("ZheeSign là phần mềm tự do theo giấy phép GNU GPL-3.0. Dựa trên Ksign của vulnnull, Nyasami/Ksign và Feather của khcrysalis.")
							.font(.footnote)
							.foregroundStyle(.secondary)
						
						Divider()
						
						ForEach([
							("vulnnull", "Ksign"),
							("Nyasami", "Ksign"),
							("khcrysalis", "Feather"),
						], id: \.0) { github, desc in
							Button {
								openURL("https://github.com/\(github)")
							} label: {
								HStack(spacing: 12) {
									AsyncImage(url: URL(string: "https://github.com/\(github).png")) { phase in
										if let image = phase.image {
											image.resizable()
										} else {
											Color.gray.opacity(0.3)
										}
									}
									.frame(width: 44, height: 44)
									.clipShape(RoundedRectangle(cornerRadius: 10))
									
									VStack(alignment: .leading, spacing: 2) {
										Text(github)
											.font(.headline)
										Text(desc)
											.font(.caption)
											.foregroundStyle(.secondary)
									}
									
									Spacer()
									
									Image(systemName: "arrow.up.right")
										.foregroundStyle(.secondary)
								}
							}
							.buttonStyle(.plain)
							
							if github != "khcrysalis" {
								Divider()
							}
						}
					}
					.padding(18)
					.background(
						RoundedRectangle(cornerRadius: 20)
							.fill(Color(.secondarySystemBackground))
					)
					.padding(.horizontal, 16)
					
					Text(Bundle.main.bundleIdentifier ?? "")
						.font(.caption2)
						.foregroundStyle(.tertiary)
						.frame(maxWidth: .infinity)
						.padding(.top, 4)
				}
				
				Spacer(minLength: 30)
			}
		}
		.navigationTitle("Giới thiệu")
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
				animate = true
			}
		}
	}
	
	private func openURL(_ string: String) {
		if let url = URL(string: string) {
			UIApplication.shared.open(url)
		}
	}
}

// MARK: - Nút liên hệ
private struct LinkButton: View {
	let icon: String
	let title: String
	let colors: [Color]
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 8) {
				Image(systemName: icon)
					.font(.subheadline.bold())
				Text(title)
					.font(.subheadline.bold())
			}
			.foregroundColor(.white)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 12)
			.background(
				RoundedRectangle(cornerRadius: 14)
					.fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
					.shadow(color: colors.first!.opacity(0.4), radius: 8)
			)
		}
	}
}
