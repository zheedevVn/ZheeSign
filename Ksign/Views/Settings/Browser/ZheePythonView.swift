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
	
	private var outputText: some View {
		Group {
			if runner.output.characters.isEmpty {
				Text("Gõ 'help' để xem lệnh.\n")
			} else {
				Text(runner.output)
			}
		}
	}
	@ObservedObject var runner = ZheePythonRunner.shared
	@ObservedObject var keeper = ZheeBackgroundKeeper.shared
	@State private var showExtraButtons = false
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
						outputText
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
			
			// Ô nhập lệnh kiểu Messenger: mũi tên mở rộng + ô nhập gọn + nút gửi
			VStack(spacing: 0) {
				// Hàng nút mở rộng (hiện khi bấm mũi tên)
				if showExtraButtons {
					HStack(spacing: 20) {
						Button {
							showFilePicker = true
						} label: {
							VStack(spacing: 4) {
								Image(systemName: "folder.fill")
									.font(.title2)
									.foregroundColor(.blue)
								Text("File .py")
									.font(.caption2)
									.foregroundColor(.secondary)
							}
						}
						.disabled(runner.isRunning)
						
						Button {
							if keeper.isKeepingAlive {
								keeper.stop()
							} else {
								if !keeper.start() {
									// Báo lỗi cho user biết
									runner.appendError("Chạy nền lỗi: \(keeper.lastError ?? "không rõ")\n")
								} else {
									runner.appendOutput("Đã bật chạy nền - Python sẽ chạy khi thoát app\n")
								}
							}
						} label: {
							VStack(spacing: 4) {
								Image(systemName: keeper.isKeepingAlive ? "server.rack.fill" : "server.rack")
									.font(.title2)
									.foregroundColor(keeper.isKeepingAlive ? .orange : .secondary)
								Text(keeper.isKeepingAlive ? "Đang chạy nền" : "Chạy nền")
									.font(.caption2)
									.foregroundColor(.secondary)
							}
						}
						
						Spacer()
					}
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.transition(.move(edge: .bottom).combined(with: .opacity))
				}
				
				HStack(alignment: .center, spacing: 8) {
					// Mũi tên mở rộng
					Button {
						withAnimation(.spring(response: 0.3)) {
							showExtraButtons.toggle()
						}
					} label: {
						Image(systemName: showExtraButtons ? "chevron.down" : "chevron.right")
							.font(.system(size: 18, weight: .semibold))
							.foregroundColor(.accentColor)
							.frame(width: 32, height: 32)
					}
					
					// Ô nhập gọn
					TextEditor(text: $inputText)
					.scrollContentBackground(.hidden)
					.font(.system(size: 14, design: .monospaced))
					.foregroundColor(.white)
					.frame(minHeight: 22, maxHeight: 110)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.horizontal, 10)
					.padding(.vertical, 6)
					.background(Color(white: 0.14))
					.cornerRadius(14)
					.focused($inputFocused)
					.autocapitalization(.none)
					.autocorrectionDisabled()
					.overlay(
						Group {
							if inputText.isEmpty {
								Text("Nhập lệnh / code Python...")
									.font(.system(size: 14, design: .monospaced))
									.foregroundColor(.gray)
									.padding(.leading, 14)
									.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
									.allowsHitTesting(false)
							}
						}
					)
				// Nút gửi
				Button {
					executeInput()
				} label: {
					Image(systemName: "arrow.up.circle.fill")
						.font(.title2)
						.foregroundColor(.accentColor)
				}
				.disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || runner.isRunning)
				}
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 8)
			.background(Color.black)
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
			if runner.output.characters.isEmpty {
				runner.appendOutput("Zhee Python Terminal v1.0\n© 2026 Hồ Đức Minh\nPython 3.15 đã sẵn sàng\nGõ 'help' để xem lệnh.\n\n")
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
