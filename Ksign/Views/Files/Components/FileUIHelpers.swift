//
//  FileUIHelpers.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileUIHelpers {
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    static func swipeActions(for file: FileItem, viewModel: FilesViewModel) -> some View {
        Button(role: .destructive) {
            withAnimation {
                viewModel.deleteFile(file)
            }
        } label: {
            Label(String(localized: "删除"), systemImage: "trash")
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
        .tint(.blue)
    }
    
    
    // MARK: - File Tap Handling
    
    static func handleFileTap(
        _ file: FileItem,
        viewModel: FilesViewModel,
        selectedFileForAction: Binding<FileItem?>,
        showingActionSheet: Binding<Bool>
    ) {
        if viewModel.isEditMode == .active {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if viewModel.selectedItems.contains(file) {
                    viewModel.selectedItems.remove(file)
                } else {
                    viewModel.selectedItems.insert(file)
                }
            }
        } else {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            selectedFileForAction.wrappedValue = file
            showingActionSheet.wrappedValue = true
        }
    }
} 
