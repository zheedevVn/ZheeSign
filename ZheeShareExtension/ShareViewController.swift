import UIKit
import UniformTypeIdentifiers

/// Share Extension: takes shared text / a link and opens ZheeChat in
/// ZheeSign with the text prefilled. No App Group needed — the handoff
/// goes through the zheesign:// URL scheme.
final class ShareViewController: UIViewController {
    private let lock = NSLock()
    private var foundText: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        extractSharedText { [weak self] text in
            guard let self, let text, !text.isEmpty else {
                self?.extensionContext?.completeRequest(returningItems: nil)
                return
            }
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "zheesign://zheechat-share?text=\(encoded)") {
                extensionContext?.open(url) { [weak self] _ in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            } else {
                extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private func extractSharedText(_ completion: @escaping (String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }
        let group = DispatchGroup()
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] value, _ in
                        defer { group.leave() }
                        if let url = value as? URL {
                            self?.setFound(url.absoluteString)
                        } else if let string = value as? String {
                            self?.setFound(string)
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier) { [weak self] value, _ in
                        defer { group.leave() }
                        if let string = value as? String {
                            self?.setFoundIfEmpty(string)
                        } else if let data = value as? Data, let string = String(data: data, encoding: .utf8) {
                            self?.setFoundIfEmpty(string)
                        }
                    }
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            completion(self?.foundText)
        }
    }

    private func setFound(_ text: String) {
        lock.lock()
        foundText = text
        lock.unlock()
    }

    private func setFoundIfEmpty(_ text: String) {
        lock.lock()
        if foundText == nil { foundText = text }
        lock.unlock()
    }
}
