//
//  WebViewContainer.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var downloadManager: IPADownloadManager
    var url: URL
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        config.processPool = WKProcessPool()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates happen through bindings and coordinator
    }
    
    func handleITMSURL(_ url: URL) {
        downloadManager.handleITMSServicesURL(url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    UIAlertController.showAlertWithOk(title: .localized("成功"), message: .localized("IPA 文件正在下载！\n你可以关闭此窗口，或继续下载其他文件。"))
                case .failure(let error):
                    UIAlertController.showAlertWithOk(title: .localized("错误"), message: error.localizedDescription)
                }
            }
        }
    }
    
    func downloadDirectFile(_ url: URL) {
        downloadManager.checkFileTypeAndDownload(url: url) { result in
            switch result {
            case .success:
                UIAlertController.showAlertWithOk(title: .localized("成功"), message: .localized("IPA 文件正在下载！\n你可以关闭此窗口，或继续下载其他文件。"))
            case .failure(let error):
                UIAlertController.showAlertWithOk(title: .localized("错误"), message: error.localizedDescription)
            }
        }
    }
}
