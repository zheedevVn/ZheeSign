//
//  ZheePythonView.swift
//  ZheeSign
//
//  Terminal Python duy nhất: chạy code, pip, xem kết quả trong 1 cửa sổ.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import UniformTypeIdentifiers

struct ZheePythonView: View {
	@ObservedObject var runner = ZheePythonRunner.shared
	@State private var inputText: String = ""
	@State private var fontSize: CGFloat = 13
	@State private var showFilePicker = false
	@State private var showCodeEditor = false
	@State private var code: String = "# Viết code Python ở đây\nprint('Xin chào từ ZheeSign!')"
	@FocusState private var inputFocused: Bool
	
	var body: some View {
		VStack(spacing: 0) {
			// Terminal - gần full màn hình
			ScrollViewReader { proxy in
				ScrollView {
					VStack(alignment: .leading, spacing: 0) {
						// Banner
						HStack(spacing: 6) {
							Text("Z")
								.font(.system(size: 11, weight: .black))
								.foregroundColor(.white)
								.frame(width: 20, height: 20)
								.background(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
								.clipShape(RoundedRectangle(cornerRadius: 6))
							Text("Zhee Python Terminal")
								.font(.caption.bold())
							Text("v1.0")
								.font(.caption2)
								.foregroundStyle(.tertiary)
							Spacer()
							// Chỉnh font
							Button { if fontSize > 9 { fontSize -= 1 } } label: {
								Image(systemName: "textformat.size.smaller").font(.caption2)
							}
							.controlSize(.mini)
							Button { if fontSize < 20 { fontSize += 1 } } label: {
								Image(systemName: "textformat.size.larger").font(.caption2)
							}
							.controlSize(.mini)
						}
						.padding(.bottom, 8)
						
						// Output (AttributedString co mau rieng cho lenh/ket qua/loi)
						Text(runner.output.isEmpty ? AttributedString("Gõ 'help' để xem lệnh.\n") : runner.output)
							.font(.system(size: fontSize, design: .monospaced))
							.foregroundColor(.green)
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.id("bottom")
					}
					.padding(10)
				}
				.background(Color.black)
				.onChange(of: runner.output) { _ in
					withAnimation {
						proxy.scrollTo("bottom", anchor: .bottom)
					}
				}
			}
			
			// Ô nhập lệnh nhiều dòng (Enter = xuống dòng, nút gửi để chạy)
			HStack(alignment: .bottom, spacing: 8) {
				Text("❯")
					.font(.system(size: 14, weight: .bold, design: .monospaced))
					.foregroundColor(.green)
					.padding(.bottom, 10)
				TextEditor(text: $inputText)
					.font(.system(size: 14, design: .monospaced))
					.frame(minHeight: 38, maxHeight: 110)
					.padding(6)
					.background(Color(.secondarySystemBackground))
					.cornerRadius(10)
					.focused($inputFocused)
					.autocapitalization(.none)
					.autocorrectionDisabled()
					.overlay(
						Group {
							if inputText.isEmpty {
								Text("Nhập lệnh / code Python... (Enter xuống dòng)")
									.font(.system(size: 13, design: .monospaced))
									.foregroundColor(.gray)
									.padding(.leading, 12)
									.padding(.top, 14)
									.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
									.allowsHitTesting(false)
							}
						}
					)
				Button {
					showFilePicker = true
				} label: {
					Image(systemName: "folder.fill")
						.font(.title3)
						.foregroundColor(.blue)
				}
				.disabled(runner.isRunning)
				.padding(.bottom, 8)
				Button {
					executeInput()
				} label: {
					Image(systemName: "arrow.up.circle.fill")
						.font(.title2)
						.foregroundColor(.green)
				}
				.disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || runner.isRunning)
				.padding(.bottom, 6)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 8)
			.background(Color(.systemBackground))
		}
		.navigationTitle("Python")
		.navigationBarTitleDisplayMode(.inline)
		.fileImporter(
			isPresented: $showFilePicker,
			allowedContentTypes: [UTType(filenameExtension: "py") ?? .plainText],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				if let url = urls.first, url.startAccessingSecurityScopedResource() {
					runner.runFile(at: url)
					url.stopAccessingSecurityScopedResource()
				}
			case .failure(let error):
				runner.appendOutput("Lỗi chọn file: \(error.localizedDescription)\n")
			}
		}
		.sheet(isPresented: $showCodeEditor) {
			NavigationView {
				VStack {
					TextEditor(text: $code)
						.font(.system(size: 14, design: .monospaced))
						.padding(8)
					HStack {
						Button("Hủy") { showCodeEditor = false }
							.buttonStyle(.bordered)
						Spacer()
						Button {
							showCodeEditor = false
							runner.runCode(code)
						} label: {
							HStack(spacing: 6) {
								Image(systemName: "play.fill").font(.caption)
								Text("Chạy").bold()
							}
						}
						.buttonStyle(.borderedProminent)
						.tint(.green)
					}
					.padding()
				}
				.navigationTitle("Viết code")
				.navigationBarTitleDisplayMode(.inline)
			}
		}
		.onAppear {
			if runner.output.isEmpty {
				runner.appendOutput("Zhee Python Terminal v1.0\n© 2026 Hồ Đức Minh\nGõ 'help' để xem lệnh.\n\n")
			}
		}
	}
	
	private func executeInput() {
		let cmd = inputText.trimmingCharacters(in: .whitespaces)
		guard !cmd.isEmpty else { return }
		inputText = ""
		inputFocused = false
		
		let lower = cmd.lowercased()
		if lower == "open" || lower == "file" {
			runner.appendCommand("❯ \(cmd)\n")
			showFilePicker = true
		} else if lower == "edit" || lower == "code" {
			runner.appendCommand("❯ \(cmd)\n")
			showCodeEditor = true
		} else {
			runner.executeCommand(cmd)
		}
	}
}

#Preview {
	NavigationView {
		ZheePythonView()
	}
}
