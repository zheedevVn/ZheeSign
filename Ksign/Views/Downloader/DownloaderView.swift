//
//  DownloaderView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import UniformTypeIdentifiers
import NimbleViews
import UIKit

struct DownloaderView: View {
    @StateObject private var downloadManager = IPADownloadManager()
    @StateObject private var libraryManager = DownloadManager.shared
    
    @State private var selectedItem: DownloadItem?
    @State private var webViewURL: URL?
    @State private var shareItems: [Any] = []
    @State private var showDocumentPicker = false
    @State private var fileToExport: URL?
    @State private var _searchText = ""
    
    private var filteredDownloadItems: [DownloadItem] {
        let items = downloadManager.finishedItems
        if _searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.title.localizedCaseInsensitiveContains(_searchText) }
        }
    }

    var body: some View {
        NBNavigationView(.localized("下载")) {
            List {
                if !libraryManager.downloads.isEmpty || !downloadManager.activeItems.isEmpty {
                    NBSection(.localized("下载中"), secondary: (libraryManager.downloads.count + downloadManager.activeItems.count).description) {
                        ForEach(libraryManager.downloads) { download in
                            AppStoreDownloadItemRow(download: download)
                        }
                        ForEach(downloadManager.activeItems) { item in
                            DownloadItemRow(
                                item: item,
                                shareItems: $shareItems,
                                importIpaToLibrary: { item in importIpaToLibrary(item) },
                                exportToFiles: { item in exportToFiles(item) },
                                deleteItem: { item in deleteItem(item) }
                            )
                        }
                    }
                }
                
                NBSection(.localized("已下载"), secondary: filteredDownloadItems.count.description) {
                    ForEach(filteredDownloadItems) { item in
                        DownloadItemRow(
                            item: item,
                            shareItems: $shareItems,
                            importIpaToLibrary: { item in importIpaToLibrary(item) },
                            exportToFiles: { item in exportToFiles(item) },
                            deleteItem: { item in deleteItem(item) }
                        )
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if downloadManager.finishedItems.isEmpty && downloadManager.activeItems.isEmpty && libraryManager.downloads.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(.localized("暂无已下载的 IPA"), systemImage: "square.and.arrow.down.fill")
                        } description: {
                            Text(.localized("先下载你的第一个 IPA 文件吧。"))
                        } actions: {
                            Button {
                                _addDownload()
                            } label: {
                                Text("添加下载").bg()
                            }
                        }
                    }
                }
            }
            .searchable(text: $_searchText, placement: .platform())
            .toolbar {
                NBToolbarButton(
                    "Add",
                    systemImage: "plus",
                    placement: .topBarTrailing
                ) {
                   _addDownload()
                }
            }
            .onChange(of: libraryManager.downloads.count) { _ in
                downloadManager.loadDownloadedIPAs()
            }
            .onChange(of: downloadManager.activeItems.count) { _ in
                downloadManager.loadDownloadedIPAs()
            }
            .fullScreenCover(item: $webViewURL) { url in
                webViewSheet(url: url)
            }
            .sheet(isPresented: $showDocumentPicker) {
                documentPickerSheet
            }
        }
    }
}


// MARK: - Alert & Sheet Content
private extension DownloaderView {
    
    @ViewBuilder
    var actionSheetContent: some View {
        if let selectedItem = selectedItem {
            Button("分享") {
                shareItem(selectedItem)
            }
            
            Button("导入到资源库") {
                importIpaToLibrary(selectedItem)
            }
            
            Button("导出到“文件”App") {
                exportToFiles(selectedItem)
            }
            
            Button("删除", role: .destructive) {
                deleteItem(selectedItem)
            }
            
            Button("取消", role: .cancel) {}
        }
    }
    
    func webViewSheet(url: URL) -> some View {
        WebViewSheet(
            downloadManager: downloadManager,
            url: url,
        )
    }
    
    @ViewBuilder
    var documentPickerSheet: some View {
        if let fileURL = fileToExport {
            FileExporterRepresentableView(
                urlsToExport: [fileURL],
                asCopy: true,
                useLastLocation: false,
                onCompletion: { _ in
                    showDocumentPicker = false
                }
            )
        }
    }

}

// MARK: - Action Handlers
private extension DownloaderView {
    func _addDownload() {
        UIAlertController.showAlertWithTextBox(
            title: .localized("输入链接"),
            message: .localized("""
Enter the URL of the website containing the IPA file (Direct install/ITMS Services) or URL to the IPA file, supported: 
- https://example.com
- itms-services://?url=https://example.com
- https://example.com/app.ipa
"""),
            textFieldPlaceholder: .localized("https://example.com"),
            submit: .localized("好的"),
            cancel: .localized("取消"),
            onSubmit: { url in
                handleURLInput(url: url)
            }
        )
    }

    func handleURLInput(url: String) {
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        var finalUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalUrl.lowercased().hasPrefix("http://") && !finalUrl.lowercased().hasPrefix("https://") {
            finalUrl = "https://" + finalUrl
        }
        
        guard let validUrl = URL(string: finalUrl) else {
            UIAlertController.showAlertWithOk(title: .localized("错误"), message: .localized("链接格式无效"))
            return
        }
        
        print(validUrl)
        
        if downloadManager.isIPAFile(validUrl) {
            downloadManager.checkFileTypeAndDownload(url: validUrl) { result in
                switch result {
                case .success:
                    UIAlertController.showAlertWithOk(title: .localized("成功"), message: .localized("IPA 文件正在下载！\n你可以关闭此窗口，或继续下载其他文件。"))
                case .failure(let error):
                    UIAlertController.showAlertWithOk(title: .localized("错误"), message: error.localizedDescription)
                }
            }
        } else {
            print("validUrl: \(validUrl)")
            webViewURL = validUrl
        }
    }
    
    func shareItem(_ item: DownloadItem) {
        shareItems = [item.localPath]
        UIActivityViewController.show(activityItems: shareItems)
    }
    
    private func importIpaToLibrary(_ file: DownloadItem) {
        let id = "FeatherManualDownload_\(UUID().uuidString)"
        let download = self.libraryManager.startArchive(from: file.url, id: id)
        libraryManager.handlePachageFile(url: file.url, dl: download) { err in
            DispatchQueue.main.async {
                if (err != nil) {
                    UIAlertController.showAlertWithOk(
                        title: .localized("错误"),
                        message: .localized("哎呀，解压文件时出错了。\n试试在设置里切换一下解压库？"),
                    )
                }
                if let index = libraryManager.getDownloadIndex(by: download.id) {
                    libraryManager.downloads.remove(at: index)
                }
            }
        }
    }
    
    func exportToFiles(_ item: DownloadItem) {
        fileToExport = item.localPath
        showDocumentPicker = true
    }
    
    func deleteItem(_ item: DownloadItem) {
        if !item.isFinished {
            downloadManager.cancelDownload(item)
            return
        }
        
        do {
            try FileManager.default.removeItem(at: item.localPath)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if let index = downloadManager.downloadItems.firstIndex(where: { $0.id == item.id }) {
                    downloadManager.downloadItems.remove(at: index)
                }
            }
        } catch {
            UIAlertController.showAlertWithOk(title: .localized("错误"), message: error.localizedDescription)
        }
    }
} 
