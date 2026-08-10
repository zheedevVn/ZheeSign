//
//  FileRow.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileRow: View {
    let file: FileItem
    let isSelected: Bool
    @ObservedObject var viewModel: FilesViewModel
    @Binding var plistFileURL: URL?
    @Binding var hexEditorFileURL: URL?
    @Binding var quickLookFileURL: URL?
    @Binding var textEditorFileURL: URL?
    @Binding var shareItems: [Any]
    @Binding var moveFileItem: FileItem?
    
    let onExtractArchive: (FileItem) -> Void
    let onPackageApp: (FileItem) -> Void
    let onImportIpa: (FileItem) -> Void
    let onNavigateToDirectory: ((URL) -> Void)?
    
    init(
        file: FileItem, 
        isSelected: Bool, 
        viewModel: FilesViewModel,
        plistFileURL: Binding<URL?>,
        hexEditorFileURL: Binding<URL?>,
        textEditorFileURL: Binding<URL?>,
        quickLookFileURL: Binding<URL?>,
        shareItems: Binding<[Any]>,
        moveFileItem: Binding<FileItem?>,
        onExtractArchive: @escaping (FileItem) -> Void,
        onPackageApp: @escaping (FileItem) -> Void,
        onImportIpa: @escaping (FileItem) -> Void,
        onNavigateToDirectory: ((URL) -> Void)? = nil
    ) {
        self.file = file
        self.isSelected = isSelected
        self.viewModel = viewModel
        self._plistFileURL = plistFileURL
        self._hexEditorFileURL = hexEditorFileURL
        self._textEditorFileURL = textEditorFileURL
        self._quickLookFileURL = quickLookFileURL
        self._shareItems = shareItems
        self._moveFileItem = moveFileItem
        self.onExtractArchive = onExtractArchive
        self.onPackageApp = onPackageApp
        self.onImportIpa = onImportIpa
        self.onNavigateToDirectory = onNavigateToDirectory
    }
    
    @State private var showingConfirmationDialog = false
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if file.isDirectory {
                    if file.isAppDirectory {
                        Image(systemName: "app.badge")
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                    }
                } else if file.isImageFile {
                    ImageRow(file: file)
                } else if file.isArchive {
                    Image(systemName: "doc.zipper")
                        .foregroundColor(.accentColor)
                } else if file.isPlistFile {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.accentColor)
                } else if file.isP12Certificate {
                    Image(systemName: "key")
                        .foregroundColor(.accentColor)
                } else if file.isKsignFile {
                    Image(systemName: "questionmark")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "doc")
                        .foregroundColor(.accentColor)
                }
            }
            .font(.title2)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .animation(.spring(), value: file.isDirectory)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if !file.isDirectory {
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let date = file.creationDate {
                        if !file.isDirectory {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            if viewModel.isEditMode == .inactive {
                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
            else {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 22))
                }
                else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 22))
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isEditMode == .active {
                if viewModel.selectedItems.contains(file) {
                    viewModel.selectedItems.remove(file)
                } else {
                    viewModel.selectedItems.insert(file)
                }
            } else if file.isDirectory {
                onNavigateToDirectory?(file.url)
            } else {
                showingConfirmationDialog = true
            }
        }
        .confirmationDialog(
            file.name,
            isPresented: $showingConfirmationDialog,
            titleVisibility: .visible
        ) {
            fileConfirmationDialogButtons()
        }
        .contextMenu {
            fileConfirmationDialogButtons()
        }
    }
    
    @ViewBuilder
    private func fileConfirmationDialogButtons() -> some View {
        if !file.isDirectory {
            Button {
                quickLookFileURL = file.url
            } label: {
                Label(String(localized: "预览"), systemImage: "eye")
            }
        }
        
        if file.isTextFile {
            Button {
                textEditorFileURL = file.url
            } label: {
                Label(String(localized: "文本编辑器"), systemImage: "doc.plaintext")
            }
        }
        
        if file.isPlistFile {
            Button {
                plistFileURL = file.url
            } label: {
                Label(String(localized: "Plist 编辑器"), systemImage: "list.bullet")
            }
        }
        
        if !file.isDirectory {
            Button {
                hexEditorFileURL = file.url
            } label: {
                Label(String(localized: "十六进制编辑器"), systemImage: "doc.text")
            }
        }
        
        if file.isP12Certificate {
            Button {
                viewModel.importCertificate(file)
            } label: {
                Label(String(localized: "导入证书"), systemImage: "key")
            }
        }
        
        if file.isKsignFile {
            Button {
                UIAlertController.showAlertWithOk(title: "?", message: .localized("自 v1.5.1 起不再支持 Ksign 证书文件（.ksign），请改用 .p12 与 .mobileprovision。"))
            } label: {
                Label(String(localized: "导入证书"), systemImage: "questionmark")
            }
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "ipa" {
            Button {
                onImportIpa(file)
            } label: {
                Text(String(localized: "导入到资源库"))
                Image(systemName: "square.grid.2x2.fill")
            }
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "app" {
            Button {
                onPackageApp(file)
            } label: {
                Label(String(localized: "打包为 IPA"), systemImage: "doc.zipper")
            }
        }
        
        if file.isArchive {
            Button {
                onExtractArchive(file)
            } label: {
                Label(String(localized: "解压"), systemImage: "doc.zipper")
            }
        }

        Button {
            moveFileItem = file
        } label: {
            Label(String(localized: "移动"), systemImage: "folder")
        }
        
        Button {
            UIAlertController.showAlertWithTextBox(
                title: .localized("重命名"),
                message: .localized("输入新的名称"),
                textFieldPlaceholder: .localized("文件名"),
                textFieldText: file.name,
                submit: .localized("重命名"),
                cancel: .localized("取消"),
                onSubmit: { name in
                    viewModel.renameFile(newName: name, item: file)
                }
            )
        } label: {
            Label(String(localized: "重命名"), systemImage: "pencil")
        }
        
        Button {
            shareItems = [file.url]
            UIActivityViewController.show(activityItems: shareItems)
        } label: {
            Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
        }
        
        Button(role: .destructive) {
            viewModel.deleteFile(file)
        } label: {
            Label(String(localized: "删除"), systemImage: "trash")
        }
    }
}
