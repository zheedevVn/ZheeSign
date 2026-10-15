//
//  ZheeUnzip.swift
//  ZheeSign
//
//  Created by Ho Duc Minh on 15/10/2026.
//  Copyright © 2026 Ho Duc Minh. All rights reserved.
//
//  Unzip helper: the `Zip` library rejects .ipa/.apk unless the extension
//  is registered first (AppFileHandler does this per-import; a fresh
//  analyzer session never did). Register them, then fall back to
//  ZIPFoundation (no extension check) if Zip still fails.

import Foundation
import Zip
import ZIPFoundation

enum ZheeUnzipError: LocalizedError {
    case cannotOpen
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen: return "Không mở được file nén."
        case .extractionFailed(let detail): return "Giải nén thất bại: \(detail)"
        }
    }
}

enum ZheeUnzip {
    static func extract(_ archiveURL: URL, to destination: URL) throws {
        Zip.addCustomFileExtension("ipa")
        Zip.addCustomFileExtension("tipa")
        Zip.addCustomFileExtension("apk")
        var zipError: Error?
        do {
            try Zip.unzipFile(archiveURL, destination: destination, overwrite: true, password: nil, progress: nil)
            return
        } catch {
            zipError = error
            // Fall through to ZIPFoundation retry below.
        }
        // Clear any partial extraction so the retry starts clean.
        let fm = FileManager.default
        try? fm.removeItem(at: destination)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ZheeUnzipError.extractionFailed(zipError?.localizedDescription ?? "Không mở được file nén.")
        }
        do {
            for entry in archive {
                guard !entry.path.hasSuffix("/") else { continue }
                let dest = destination.appendingPathComponent(entry.path)
                // Zip-Slip guard
                guard dest.path.hasPrefix(destination.path) else { continue }
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: dest)
            }
        } catch {
            throw ZheeUnzipError.extractionFailed(error.localizedDescription)
        }
    }
}
