//
//  PhotoManager.swift
//  iPadPhotoViewer
//
//  Created by matsuohiroki on 2025/05/31.
//
//

import SwiftUI
import Combine
import Photos

final class PhotoManager: ObservableObject {
    @Published var photos: [URL] = []

    private let fileManager = FileManager.default
    private let docsDir: URL

    init() {
        // ドキュメントディレクトリを取得
        docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadPhotos()
    }

    /// ドキュメントディレクトリから画像ファイルを読み込み、photos 配列を更新する
    func loadPhotos() {
        do {
            let allFiles = try fileManager.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil)
            // 画像として扱いたい拡張子をフィルタリング（必要に応じて追加）
            photos = allFiles.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "heic"
            }
        } catch {
            print("📂 PhotoManager: ドキュメントディレクトリ読み込みエラー: \(error)")
            photos = []
        }
    }
}


extension PhotoManager {
    /// PHAsset をドキュメントディレクトリに保存し、カメラロールから削除する
    func `import`(asset: PHAsset, completion: @escaping (Bool) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .original
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data = data else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // ユニークなファイル名（例：asset.localIdentifier を利用）
            let filename = (asset.value(forKey: "filename") as? String) ?? UUID().uuidString
            let destURL = self.docsDir.appendingPathComponent(filename)
            do {
                try data.write(to: destURL)
            } catch {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            completion(true)
        }
    }
    
    func deletePhoto(at index: Int) {
        guard index >= 0 && index < photos.count else { return }
        let urlToDelete = photos[index]
        do {
            try fileManager.removeItem(at: urlToDelete)
            } catch {
                print("❌ Failed to delete photo: \(error)")
            }
        // Refresh the array so the UI updates
        loadPhotos()
    }
    
}
