//
//  CertificatesView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit

// MARK: - View
struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	
	@State private var _isAddingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	//
	private var _bindingSelectedCert: Binding<Int>?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}
	
	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}
	
	// MARK: Body
	var body: some View {
		NBGrid {
			ForEach(Array(certificates.enumerated()), id: \.element.uuid) { index, cert in
				_cellButton(for: cert, at: index)
			}
		}
		.navigationTitle(.localized("证书"))
		.navigationBarTitleDisplayMode(.inline)
        .overlay {
            if certificates.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("暂无证书"), systemImage: "questionmark.folder.fill")
                    } description: {
                        Text(.localized("先导入你的第一个证书，即可开始签名。"))
                    } actions: {
                        Button {
                            _isAddingPresenting = true
                        } label: {
							Text("导入").bg()
                        }
                    }
                }
            }
        }
		.toolbar {
			if _bindingSelectedCert == nil {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing
				) {
					_isAddingPresenting = true
				}
			}
			if certificates.count > 0 {
			NBToolbarButton(
				systemImage: "arrow.counterclockwise",
				style: .icon,
				placement: .topBarTrailing
				) {
					for cert in certificates {
						Storage.shared.revokagedCertificate(for: cert)
					}
				}
			}
		}
		.sheet(item: $_isSelectedInfoPresenting) { cert in
			CertificatesInfoView(cert: cert)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
				.presentationDetents([.medium])
		}
	}
}

extension CertificatesView {
	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		Button {
			_selectedCertBinding.wrappedValue = index
		} label: {
			CertificatesCellView(
				cert: cert
			)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: _cornerRadius)
					.fill(Color(uiColor: .quaternarySystemFill))
			)
			.overlay(
				RoundedRectangle(cornerRadius: _cornerRadius)
					.strokeBorder(
						_selectedCertBinding.wrappedValue == index ? Color.accentColor : Color.clear,
						lineWidth: 2
					)
			)
			.contextMenu {
				_contextActions(for: cert)
				Divider()
				_actions(for: cert)
			}
			.animation(.smooth, value: _selectedCertBinding.wrappedValue)
		}
		.buttonStyle(.plain)
	}
    
    private var _cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 28.0
        } else {
            return 17.0
        }
    }
    
	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
		Button(role: .destructive) {
			if certificates.count == 1 {
                UIAlertController.showAlertWithOk(
                    title: .localized("此操作不可撤销！"),
                    message: .localized("你不会想把唯一的证书删掉吧 >.<?"),
                    isCancel: true
                )
            } else {
                Storage.shared.deleteCertificate(for: cert)
            }
		} label: {
			Label(.localized("删除"), systemImage: "trash")
		}
	}
	
	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
		Button {
			_isSelectedInfoPresenting = cert
		} label: {
			Label(.localized("查看信息"), systemImage: "info.circle")
		}
	}
	

}
