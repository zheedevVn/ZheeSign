//
//  ZheePythonRunner.swift
//  ZheeSign
//
//  Chạy Python ngay trong app bằng CPython nhúng.
//  © 2026 Hồ Đức Minh
//

import Foundation
import SwiftUI

enum ZheeOutputStyle {
	case command  // lenh nguoi dung go - noi bat
	case result   // ket qua chay - xanh la
	case error    // loi - do
	case info     // thong tin - xam
}

class ZheePythonRunner: ObservableObject {
	static let shared = ZheePythonRunner()
	
	@Published var output = AttributedString("")
	@Published var isRunning = false
	@Published var installedPackages: [String] = []
	
	private var pythonInitialized = false
	
	private init() {}
	
	// Khởi tạo Python interpreter
	func initialize() {
		guard !pythonInitialized else { return }
		
		guard PythonBridge.shared.isAvailable else {
			appendError("Lỗi: Python framework chưa được nhúng\n")
			return
		}
		
		// Đường dẫn thư viện Python trong bundle - KIEM TRA KY truoc khi init
		guard let resourcePath = Bundle.main.resourcePath else {
			appendError("Lỗi: không tìm thấy bundle\n")
			return
		}
		let pythonHome = (resourcePath as NSString).appendingPathComponent("python")
		let stdlibCheck = (pythonHome as NSString).appendingPathComponent("lib/python3.15/os.py")
		guard FileManager.default.fileExists(atPath: stdlibCheck) else {
			appendError("Lỗi: thiếu thư viện chuẩn Python (os.py)\n")
			appendOutput("Hãy cài bản mới nhất từ Releases.\n")
			return
		}
		
		setenv("PYTHONHOME", pythonHome, 1)
		let docsPath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString)
		let userSite = docsPath.appendingPathComponent("site-packages")
		try? FileManager.default.createDirectory(atPath: userSite, withIntermediateDirectories: true)
		let pythonPath = pythonHome + "/lib/python3.15:"
			+ pythonHome + "/lib/python3.15/lib-dynload:"
			+ pythonHome + "/lib/python3.15/site-packages:"
			+ userSite
		setenv("PYTHONPATH", pythonPath, 1)
		
		// SSL cert cho pip (dung certifi di kem)
		let certPath = (pythonHome as NSString).appendingPathComponent("lib/python3.15/site-packages/certifi/cacert.pem")
		if FileManager.default.fileExists(atPath: certPath) {
			setenv("SSL_CERT_FILE", certPath, 1)
		}
		
		// Khởi tạo Python
		PythonBridge.shared.initialize()
		pythonInitialized = true
	}
	
	// Chạy code Python
	func runCode(_ code: String) {
		guard !isRunning else { return }
		initialize()
		
		isRunning = true
		appendCommand("$ python\n")
		
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			// Chuyển hướng stdout/stderr
			let result = self?.executePython(code) ?? "Lỗi: không thể chạy Python"
			
			DispatchQueue.main.async {
				if result.contains("Traceback") || result.contains("[Lỗi khi chạy code]") {
					self?.appendError(result + "\n")
				} else {
					self?.appendOutput(result + "\n")
				}
				self?.isRunning = false
			}
		}
	}
	
	// Chạy file Python
	func runFile(at url: URL) {
		guard let code = try? String(contentsOf: url, encoding: .utf8) else {
			appendError("Lỗi: không đọc được file\n")
			return
		}
		appendCommand("Chạy file: \(url.lastPathComponent)\n")
		runCode(code)
	}
	
	// pip install that: tai wheel pure-Python tu PyPI (khong can pip/subprocess)
	func pipInstall(_ package: String) {
		guard !isRunning else { return }
		initialize()
		guard pythonInitialized else { return }
		
		isRunning = true
		appendCommand("$ pip install \(package)\n")
		
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let safePkg = package.replacingOccurrences(of: "\"", with: "")
			let code = """
			import urllib.request, zipfile, json, os
			_pkg = "\(safePkg)"
			_site = os.path.expanduser("~/Documents/site-packages")
			os.makedirs(_site, exist_ok=True)
			try:
			    _api = "https://pypi.org/pypi/" + _pkg + "/json"
			    _data = json.loads(urllib.request.urlopen(_api, timeout=30).read())
			    _whl = None
			    for _f in _data.get("urls", []):
			        _fn = _f.get("filename", "")
			        if _f.get("packagetype") == "bdist_wheel" and (_fn.endswith("-py3-none-any.whl") or _fn.endswith("-py2.py3-none-any.whl")):
			            _whl = _f["url"]
			            break
			    if not _whl:
			        print("Khong co ban pure-Python cho " + _pkg)
			    else:
			        print("Dang tai " + _pkg + "...")
			        _tmp = "/tmp/_zheepkg.whl"
			        urllib.request.urlretrieve(_whl, _tmp)
			        with zipfile.ZipFile(_tmp) as _z:
			            _z.extractall(_site)
			        os.remove(_tmp)
			        print("Da cai " + _pkg)
			except Exception as _e:
			    print("Loi: " + str(_e))
			"""
			let result = self?.executePython(code) ?? "Lỗi"
			
			DispatchQueue.main.async {
				if result.contains("Loi:") || result.contains("Traceback") {
					self?.appendError(result + "\n")
				} else {
					self?.appendOutput(result + "\n")
				}
				self?.isRunning = false
				self?.refreshPackages()
			}
		}
	}
	
	// Liệt kê packages đã cài
	func refreshPackages() {
		let code = """
		import pkg_resources
		for d in pkg_resources.working_set:
		    print(d.key + "==" + d.version)
		"""
		// Chạy đồng bộ đơn giản
	}
	
	func clearOutput() {
		output = AttributedString("")
	}
	
	func showHelp() {
		appendOutput("""
		Lệnh có sẵn:
		  help              - Hiện trợ giúp
		  clear / cls       - Xóa màn hình
		  open              - Mở file .py từ máy
		  edit              - Mở trình viết code
		  pip install <pkg> - Cài thư viện
		  <code python>     - Chạy code Python trực tiếp
		
		""")
	}
	
	// Xử lý lệnh từ terminal
	func executeCommand(_ cmd: String) {
		let sanitized = cmd
			.replacingOccurrences(of: "\u{201C}", with: "\"")
			.replacingOccurrences(of: "\u{201D}", with: "\"")
			.replacingOccurrences(of: "\u{2018}", with: "'")
			.replacingOccurrences(of: "\u{2019}", with: "'")
		let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
		let lower = trimmed.lowercased()
		
		// Hiển thị lệnh đã nhập
		appendCommand("❯ \(trimmed)\n")
		
		if lower == "help" {
			showHelp()
		} else if lower == "clear" || lower == "cls" {
			clearOutput()
		} else if lower.hasPrefix("pip install ") {
			let pkg = String(trimmed.dropFirst("pip install ".count)).trimmingCharacters(in: .whitespaces)
			if !pkg.isEmpty {
				pipInstall(pkg)
			} else {
				appendOutput("Dùng: pip install <tên package>\n")
			}
		} else if lower.hasPrefix("pip ") {
			appendOutput("Chỉ hỗ trợ: pip install <tên package>\n")
		} else {
			// Chạy như code Python
			runCode(trimmed)
		}
	}
	
	func appendOutput(_ text: String) {
		appendStyled(text, .result)
	}
	
	func appendCommand(_ text: String) {
		appendStyled(text, .command)
	}
	
	func appendError(_ text: String) {
		appendStyled(text, .error)
	}
	
	func appendStyled(_ text: String, _ style: ZheeOutputStyle) {
		var attr = AttributedString(text)
		switch style {
		case .command:
			attr.foregroundColor = .cyan
			attr.inlinePresentationIntent = .stronglyEmphasized
		case .result:
			attr.foregroundColor = .green
		case .error:
			attr.foregroundColor = .red
			attr.inlinePresentationIntent = .stronglyEmphasized
		case .info:
			attr.foregroundColor = .gray
		}
		DispatchQueue.main.async { [weak self] in
			self?.output += attr
		}
	}
	
	// Thực thi Python code - lay output qua file tam
	private func executePython(_ code: String) -> String {
		let bridge = PythonBridge.shared
		guard bridge.isAvailable else {
			return "Python chưa sẵn sàng"
		}
		
		let outPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("zhee_py_out.txt")
		// Xoa file cu
		try? FileManager.default.removeItem(atPath: outPath)
		
		// Chuyen huong stdout/stderr vao StringIO
		_ = bridge.runSimpleString("import sys, io\n_output_buffer = io.StringIO()\n_old_stdout, _old_stderr = sys.stdout, sys.stderr\nsys.stdout = sys.stderr = _output_buffer\n")
		
		// Chạy code người dùng
		let runResult = bridge.runSimpleString(code + "\n")
		
		// Ghi output ra file tam roi doc lai tu Swift
		_ = bridge.runSimpleString("open(r'\(outPath)','w',encoding='utf-8').write(_output_buffer.getvalue())\n")
		_ = bridge.runSimpleString("sys.stdout, sys.stderr = _old_stdout, _old_stderr\n")
		
		var out = (try? String(contentsOfFile: outPath, encoding: .utf8)) ?? ""
		try? FileManager.default.removeItem(atPath: outPath)
		
		// Goi y pip install khi thieu thu vien
		if out.contains("ModuleNotFoundError") {
			let pattern = "No module named '([^']+)'"
			if let regex = try? NSRegularExpression(pattern: pattern),
			   let match = regex.firstMatch(in: out, range: NSRange(out.startIndex..., in: out)),
			   let range = Range(match.range(at: 1), in: out) {
				let fullName = String(out[range])
				let modName = fullName.split(separator: ".").first.map(String.init) ?? fullName
				out += "\n💡 Thiếu thư viện '\(modName)' — gõ: pip install \(modName)"
			}
		}
		
		if runResult != 0 {
			return out.isEmpty ? "[Lỗi khi chạy code]" : out + "\n[Lỗi khi chạy code]"
		}
		return out.isEmpty ? "(không có output)" : out
	}
}

// MARK: - Python C API (dynamic loading)
// Load Python framework động để app vẫn chạy nếu thiếu framework

import Darwin

class PythonBridge {
	static let shared = PythonBridge()
	private var handle: UnsafeMutableRawPointer?
	
	private init() {
		// Thử load Python framework
		let paths = [
			Bundle.main.privateFrameworksPath.map { $0 + "/Python.framework/Python" },
			Bundle.main.resourcePath.map { $0 + "/Python.framework/Python" },
		].compactMap { $0 }
		
		for path in paths {
			if let h = dlopen(path, RTLD_NOW | RTLD_GLOBAL) {
				handle = h
				break
			}
		}
	}
	
	var isAvailable: Bool { handle != nil }
	
	private func lookup<T>(_ name: String, as type: T.Type) -> T? {
		guard let h = handle, let sym = dlsym(h, name) else { return nil }
		return unsafeBitCast(sym, to: T.self)
	}
	
	func initialize() {
		typealias Fn = @convention(c) () -> Void
		guard let fn: Fn = lookup("Py_Initialize", as: Fn.self) else { return }
		fn()
		// Nha GIL de thread khac dung duoc (tranh deadlock/crash)
		typealias SaveFn = @convention(c) () -> UnsafeMutableRawPointer?
		if let saveFn: SaveFn = lookup("PyEval_SaveThread", as: SaveFn.self) {
			_ = saveFn()
		}
	}
	
	func runSimpleString(_ command: String) -> Int32 {
		typealias Fn = @convention(c) (UnsafePointer<CChar>) -> Int32
		typealias EnsureFn = @convention(c) () -> Int32
		typealias ReleaseFn = @convention(c) (Int32) -> Void
		guard let fn: Fn = lookup("PyRun_SimpleString", as: Fn.self) else { return -1 }
		// Lay GIL truoc khi goi Python API tu background thread
		let gstate: Int32
		if let ensureFn: EnsureFn = lookup("PyGILState_Ensure", as: EnsureFn.self) {
			gstate = ensureFn()
		} else {
			gstate = -1
		}
		defer {
			if gstate != -1,
			   let releaseFn: ReleaseFn = lookup("PyGILState_Release", as: ReleaseFn.self) {
				releaseFn(gstate)
			}
		}
		return command.withCString { fn($0) }
	}
}
