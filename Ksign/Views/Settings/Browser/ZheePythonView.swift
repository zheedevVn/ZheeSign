//
//  ZheePythonView.swift
//  ZheeSign
//
//  Chạy Python trong app: chọn file, viết code, cài pip.
//  © 2026 Hồ Đức Minh
//

import SwiftUI
import UniformTypeIdentifiers

struct ZheePythonView: View {
	@ObservedObject var runner = ZheePythonRunner.shared
	@State private var code: String = "# Viết code Python ở đây\nprint('Xin chào từ ZheeSign!')\n\nfor i in range(5):\n    print(f'Dòng {i + 1}')"
	@State private var showFilePicker = false
	@State private var pipPackage: String = ""
	@State private var selectedTab = 0
	
	var body: some View {
		VStack(spacing: 0) {
			// Tab selector
			Picker("", selection: $selectedTab) {
				Text("Code").tag(0)
				Text("File").tag(1)
				Text("Pip").tag(2)
				Text("Console").tag(3)
			}
			.pickerStyle(.segmented)
			.padding()
			
			if selectedTab == 0 {
				codeEditorView
			} else if selectedTab == 1 {
				fileView
			} else if selectedTab == 2 {
				pipView
			} else {
				consoleView
			}
		}
		.navigationTitle("Python")
		.navigationBarTitleDisplayMode(.inline)
	}
	
	// MARK: - Code Editor
	private var codeEditorView: some View {
		VStack {
			TextEditor(text: $code)
				.font(.system(.body, design: .monospaced))
				.padding(8)
				.background(Color(.secondarySystemBackground))
				.cornerRadius(12)
				.padding(.horizontal)
			
			Button {
				selectedTab = 3
				runner.runCode(code)
			} label: {
				HStack {
					Image(systemName: "play.fill")
					Text("Chạy")
						.fontWeight(.semibold)
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(
					LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
				)
				.foregroundColor(.white)
				.cornerRadius(14)
			}
			.padding()
			.disabled(runner.isRunning)
		}
	}
	
	// MARK: - File Picker
	private var fileView: some View {
		VStack(spacing: 20) {
			Image(systemName: "doc.text.fill")
				.font(.system(size: 60))
				.foregroundStyle(
					LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
				)
			
			Text("Chọn file Python (.py) từ máy")
				.font(.headline)
			
			Text("File sẽ được chạy ngay trong app")
				.font(.subheadline)
				.foregroundStyle(.secondary)
			
			Button {
				showFilePicker = true
			} label: {
				HStack {
					Image(systemName: "folder.fill")
					Text("Chọn file")
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.blue)
				.foregroundColor(.white)
				.cornerRadius(14)
			}
			.padding(.horizontal, 40)
			
			Spacer()
		}
		.padding(.top, 40)
		.fileImporter(
			isPresented: $showFilePicker,
			allowedContentTypes: [UTType(filenameExtension: "py") ?? .plainText],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				if let url = urls.first {
					// Bắt đầu truy cập file
					if url.startAccessingSecurityScopedResource() {
						runner.runFile(at: url)
						url.stopAccessingSecurityScopedResource()
					}
					selectedTab = 3
				}
			case .failure(let error):
				runner.output += "Lỗi chọn file: \(error.localizedDescription)\n"
				selectedTab = 3
			}
		}
	}
	
	// MARK: - Pip Installer
	private var pipView: some View {
		VStack(spacing: 20) {
			Image(systemName: "shippingbox.fill")
				.font(.system(size: 60))
				.foregroundStyle(
					LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
				)
			
			Text("Cài thư viện Python")
				.font(.headline)
			
			HStack {
				TextField("Tên package (vd: requests)", text: $pipPackage)
					.textFieldStyle(.roundedBorder)
					.autocapitalization(.none)
				
				Button {
					if !pipPackage.isEmpty {
						selectedTab = 3
						runner.pipInstall(pipPackage)
						pipPackage = ""
					}
				} label: {
					Image(systemName: "arrow.down.circle.fill")
						.font(.title2)
						.foregroundColor(.blue)
				}
				.disabled(runner.isRunning || pipPackage.isEmpty)
			}
			.padding(.horizontal)
			
			Text("Các package phổ biến: requests, numpy, pillow")
				.font(.caption)
				.foregroundStyle(.secondary)
			
			Spacer()
		}
		.padding(.top, 40)
	}
	
	// MARK: - Console
	private var consoleView: some View {
		VStack {
			ScrollView {
				Text(runner.output.isEmpty ? "Console trống\nChạy code để xem kết quả" : runner.output)
					.font(.system(.body, design: .monospaced))
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding()
					.foregroundColor(runner.output.isEmpty ? .secondary : .primary)
			}
			.background(Color(.systemBackground))
			
			HStack {
				Button("Xóa") {
					runner.clearOutput()
				}
				.buttonStyle(.bordered)
				
				Spacer()
				
				if runner.isRunning {
					ProgressView()
						.progressViewStyle(.circular)
					Text("Đang chạy...")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.padding()
		}
	}
}

#Preview {
	NavigationView {
		ZheePythonView()
	}
}
