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
						
						// Output
						Text(runner.output.isEmpty ? "Gõ 'help' để xem lệnh.\n" : runner.output)
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
			
			// Thanh lệnh nhanh (nhỏ gọn)
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					quickButton("▶ Chạy", icon: "play.fill") {
						showCodeEditor = true
					}
					quickButton("📁 File", icon: "folder.fill") {
						showFilePicker = true
					}
					quickButton("📦 Pip", icon: "shippingbox.fill") {
						inputText = "pip install "
						inputFocused = true
					}
					quickButton("🗑 Xóa", icon: "trash.fill") {
						runner.clearOutput()
					}
					quickButton("❓ Help", icon: "questionmark.circle.fill") {
						runner.showHelp()
					}
				}
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
			}
			.background(Color(.secondarySystemBackground))
			
			// Ô nhập lệnh
			HStack(spacing: 8) {
				Text("❯")
					.font(.system(size: 14, weight: .bold, design: .monospaced))
					.foregroundColor(.green)
				TextField("Nhập lệnh hoặc code Python...", text: $inputText)
					.font(.system(size: 14, design: .monospaced))
					.textFieldStyle(.roundedBorder)
					.focused($inputFocused)
					.autocapitalization(.none)
					.autocorrectionDisabled()
					.onSubmit {
						executeInput()
					}
				Button {
					executeInput()
				} label: {
					Image(systemName: "arrow.up.circle.fill")
						.font(.title2)
						.foregroundColor(.green)
				}
				.disabled(inputText.isEmpty || runner.isRunning)
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
	
	private func quickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack(spacing: 4) {
				Image(systemName: icon).font(.caption2)
				Text(title).font(.caption)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(Color(.tertiarySystemBackground))
			.cornerRadius(8)
		}
		.buttonStyle(.plain)
	}
	
	private func executeInput() {
		let cmd = inputText.trimmingCharacters(in: .whitespaces)
		guard !cmd.isEmpty else { return }
		inputText = ""
		inputFocused = false
		runner.executeCommand(cmd)
	}
}

#Preview {
	NavigationView {
		ZheePythonView()
	}
}
