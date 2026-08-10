//
//  FilesView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import NimbleViews

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct FilesView: View {
    let directoryURL: URL?
    let isRootView: Bool
    @Namespace private var _namespace
    
    @StateObject private var viewModel: FilesViewModel
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var searchText = ""

    @AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false

    @State private var plistFileURL: URL?
    @State private var hexEditorFileURL: URL?
    @State private var textEditorFileURL: URL?
    @State private var quickLookFileURL: URL?
    @State private var moveSingleFile: FileItem?
    @State private var shareItems: [Any] = []
    @State private var navigateToDirectoryURL: URL?
    
    // MARK: - Initializers
    
    init() {
        self.directoryURL = nil
        self.isRootView = true
        self._viewModel = StateObject(wrappedValue: FilesViewModel())
    }
    
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.isRootView = false
        self._viewModel = StateObject(wrappedValue: FilesViewModel(directory: directoryURL))
    }
    
    private var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return viewModel.files
        } else {
            return viewModel.files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        Group {
            if isRootView {
                NavigationStack {
                    filesBrowserContent
                }
                .accentColor(.accentColor)
            } else {
                filesBrowserContent
            }
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            if !isRootView {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    // MARK: - Main Content
    
    private var filesBrowserContent: some View {
        ZStack {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                .refreshable {
                    if isRootView {
                        await withCheckedContinuation { continuation in
                            viewModel.loadFiles()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                continuation.resume()
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        addButton
                        editButton
                    }
                    NBToolbarMenu(
                        systemImage: "line.3.horizontal.decrease",
                        style: .icon,
                        placement: .topBarTrailing
                    ) {
                        _sortActions()
                    }
                    if viewModel.isEditMode == .active {
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: 12) {
                                selectAllButton
                                moveButton
                                shareButton
                                deleteButton
                            }
                        }
                    }
                }
            
        }
        .sheet(isPresented: $viewModel.showingImporter) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType.item],
                allowsMultipleSelection: true,
                onDocumentsPicked: { urls in
                    viewModel.importFiles(urls: urls)
                }
            )
        }
        .sheet(item: $moveSingleFile) { item in
            FileExporterRepresentableView(
                urlsToExport: [item.url],
                asCopy: false,
                useLastLocation: _useLastExportLocation,
                onCompletion: { _ in
                    moveSingleFile = nil
                    viewModel.loadFiles()
                }
            )
        }
        .sheet(isPresented: $viewModel.showDirectoryPicker) {
            FileExporterRepresentableView(
                urlsToExport: Array(viewModel.selectedItems.map { $0.url }),
                asCopy: false,
                useLastLocation: _useLastExportLocation,
                onCompletion: { _ in
                    viewModel.selectedItems.removeAll()
                    if viewModel.isEditMode == .active { viewModel.isEditMode = .inactive }
                
                    viewModel.loadFiles()
                }
            )
        }

        .fullScreenCover(item: $plistFileURL) { fileURL in
            PlistEditorView(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
        .fullScreenCover(item: $hexEditorFileURL) { fileURL in
            HexEditorView(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
        .fullScreenCover(item: $textEditorFileURL) { fileURL in
            TextEditorView(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
        .fullScreenCover(item: $quickLookFileURL) { fileURL in
            QuickLookPreview(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        List {
            ForEach(filteredFiles) { file in
                FileRow(
                    file: file,
                    isSelected: viewModel.selectedItems.contains(file),
                    viewModel: viewModel,
                    plistFileURL: $plistFileURL,
                    hexEditorFileURL: $hexEditorFileURL,
                    textEditorFileURL: $textEditorFileURL,
                    quickLookFileURL: $quickLookFileURL,
                    shareItems: $shareItems,
                    moveFileItem: $moveSingleFile,
                    onExtractArchive: extractArchive,
                    onPackageApp: packageAppAsIPA,
                    onImportIpa: importIpaToLibrary,
                    onNavigateToDirectory: navigateToDirectory
                )
                .swipeActions(edge: .trailing) {
                    swipeActions(for: file)
                }
                .compatMatchedTransitionSource(id: file.url.absoluteString, ns: _namespace)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $viewModel.isEditMode)
        .navigationDestination(isPresented: Binding(
            get: { navigateToDirectoryURL != nil },
            set: { if !$0 { navigateToDirectoryURL = nil } }
        )) {
            if let url = navigateToDirectoryURL {
                FilesView(directoryURL: url)
            }
        }
        .overlay {
            if filteredFiles.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("暂无文件"), systemImage: "folder.fill.badge.questionmark")
                    } description: {
                        Text(.localized("先导入你的第一个文件吧。"))
                    } actions: {
                        Button {
                            viewModel.showingImporter = true
                        } label: {
                            Text("导入文件").bg()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var navigationTitle: String {
        if let directoryURL = directoryURL {
            return directoryURL.lastPathComponent
        } else {
            return viewModel.currentDirectory.lastPathComponent
        }
    }
    

    // MARK: - Setup Methods
    
    private func setupView() {
        viewModel.loadFiles()
    }
    
   
    
    // MARK: - Toolbar Items
    
    private var addButton: some View {
        Menu {
            Button {
                viewModel.showingImporter = true
            } label: {
                Label(String(localized: "导入文件"), systemImage: "doc.badge.plus")
            }
            Button {
                UIAlertController.showAlertWithTextBox(
                    title: .localized("新建文件夹"),
                    message: .localized("输入新文件夹的名称"),
                    textFieldPlaceholder: .localized("文件夹名"),
                    submit: .localized("创建"),
                    cancel: .localized("取消"),
                    onSubmit: { name in
                        viewModel.createNewFolder(name: name)
                    }
                )
            } label: {
                Label(String(localized: "新建文件夹"), systemImage: "folder.badge.plus")
            }
            Button {
                UIAlertController.showAlertWithTextBox(
                    title: .localized("新建文本文件"),
                    message: .localized("输入新文本文件的名称"),
                    textFieldPlaceholder: .localized("文本文件名"),
                    textFieldText: "Unnamed.txt",
                    submit: .localized("创建"),
                    cancel: .localized("取消"),
                    onSubmit: { name in
                       viewModel.createNewTextFile(name: name)
                    }
                )
            } label: {
                Label(String(localized: "新建文本文件"), systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
    
    private var editButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                viewModel.isEditMode = viewModel.isEditMode == .active ? .inactive : .active
                if viewModel.isEditMode == .inactive {
                    viewModel.selectedItems.removeAll()
                }
            }
        } label: {
            Text(viewModel.isEditMode == .active ? String(localized: "完成") : String(localized: "编辑"))
        }
    }
    
    private var selectAllButton: some View {
        Button {
            if viewModel.selectedItems.isEmpty {
                for file in viewModel.files {
                    viewModel.selectedItems.insert(file)
                }
            } else {
                viewModel.selectedItems.removeAll()
            }
        } label: {
            Image(systemName: viewModel.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
        }
    }
    
    private var moveButton: some View {
        Button {
            viewModel.showDirectoryPicker = true
        } label: {
            Label(String(localized: "移动"), systemImage: "folder")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var shareButton: some View {
        Button {
            if !viewModel.selectedItems.isEmpty {
                let urls = viewModel.selectedItems.map { $0.url }
                shareItems = urls
                UIActivityViewController.show(activityItems: shareItems)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.deleteSelectedItems()
        } label: {
            Image(systemName: "trash")
        }
        .tint(.red)
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    // MARK: - Actions
    
    private func navigateToDirectory(_ url: URL) {
        navigateToDirectoryURL = url
    }
    

    
    // MARK: - File Operations
    
    private func extractArchive(_ file: FileItem) {
        guard file.isArchive else { return }
        
        let extractItem = ExtractManager.shared.start(fileName: file.name)
        ExtractionService.extractArchive(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    ExtractManager.shared.updateProgress(for: extractItem, progress: progress)
                }
            }
        ) { result in
            DispatchQueue.main.async {
                
                switch result {
                case .success:
                    withAnimation {
                        self.viewModel.loadFiles()
                    }
                    
                case .failure:
                    UIAlertController.showAlertWithOk(title: .localized("错误"), message: .localized("哎呀，解压文件时出错了。\n试试在设置里切换一下解压库？"))
                }
                ExtractManager.shared.finish(item: extractItem)
            }
        }
    }
    
    private func packageAppAsIPA(_ file: FileItem) {
        guard file.isAppDirectory else { return }
        
        let extractItem = ExtractManager.shared.start(fileName: file.name)
        ExtractionService.packageAppAsIPA(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    ExtractManager.shared.updateProgress(for: extractItem, progress: progress)
                }
            }
        ) { result in
            DispatchQueue.main.async {
                
                switch result {
                case .success(let ipaFileName):
                    self.viewModel.loadFiles()
                    UIAlertController.showAlertWithOk(title: .localized("成功"), message: .localized("已成功将 \(file.name) 打包为 \(ipaFileName)"))
                case .failure(let error):
                    UIAlertController.showAlertWithOk(title: .localized("错误"), message: .localized("打包 IPA 失败：\(error.localizedDescription)"))
                }
                ExtractManager.shared.finish(item: extractItem)
            }
        }
    }
    
    private func importIpaToLibrary(_ file: FileItem) {
        let id = "FeatherManualDownload_\(UUID().uuidString)"
        let download = self.downloadManager.startArchive(from: file.url, id: id)
        downloadManager.handlePachageFile(url: file.url, dl: download) { err in
            DispatchQueue.main.async {
                if let error = err {
                    UIAlertController.showAlertWithOk(title: .localized("错误"), message: .localized("哎呀，解压文件时出错了。\n试试在设置里切换一下解压库？"))
                } else {
                }
                if let index = DownloadManager.shared.getDownloadIndex(by: download.id) {
                    DownloadManager.shared.downloads.remove(at: index)
                }
            }
        }
    }

    
    // MARK: - UI Helpers
    
    @ViewBuilder
    private func swipeActions(for file: FileItem) -> some View {
        FileUIHelpers.swipeActions(for: file, viewModel: viewModel)
    }

    @ViewBuilder
    private func _sortActions() -> some View {
        Section(.localized("筛选")) {
            ForEach(FilesViewModel.SortOption.allCases, id: \.displayName) { opt in
                _sortButton(for: opt)
            }
        }
    }

    private func _sortButton(for option: FilesViewModel.SortOption) -> some View {
        Button {
            if viewModel.sortOption == option {
                viewModel.updateSort(option: option, ascending: !viewModel.sortAscending)
            } else {
                viewModel.updateSort(option: option, ascending: true)
            }
        } label: {
            HStack {
                Text(option.displayName)
                Spacer()
                if viewModel.sortOption == option {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                }
            }
        }
    }
}
