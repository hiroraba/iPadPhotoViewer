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
import Foundation

class PhotoManager: ObservableObject {
    @Published var photos: [URL] = []
    
    private let fileManager = FileManager.default
    
    // ドキュメントディレクトリのURLを返すプロパティ
    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    init() {
        loadPhotos()
    }
    
    /// ドキュメントディレクトリ内の画像ファイルを「ファイル作成日時（追加順）」で読み込む
    func loadPhotos() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [.creationDateKey]
            
            // ドキュメントディレクトリ以下にある全ファイルを取得
            guard let fileURLs = try? fm.contentsOfDirectory(at: self.docsDir,
                                                             includingPropertiesForKeys: Array(resourceKeys),
                                                             options: [.skipsHiddenFiles]) else {
                DispatchQueue.main.async {
                    self.photos = []
                }
                return
            }
            
            // 画像ファイルのみフィルタ（必要に応じて拡張子を追加）
            let imageURLs = fileURLs.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "heic"
            }
            
            // URLごとに creationDate を取得してタプルにまとめる
            let urlsWithDate: [(url: URL, date: Date)] = imageURLs.compactMap { url in
                if let values = try? url.resourceValues(forKeys: [.creationDateKey]),
                   let created = values.creationDate {
                    return (url, created)
                } else {
                    // 日付情報が取れなければ、極端に昔の日付（表示順末尾）にしておく
                    return (url, Date.distantPast)
                }
            }
            
            // creationDate の昇順（古いもの＝先に追加されたものが先頭）でソート
            let sortedByDate = urlsWithDate.sorted { lhs, rhs in
                lhs.date > rhs.date
            }
            
            // URL の配列だけ取り出して Published プロパティにセット
            let sortedURLs = sortedByDate.map { $0.url }
            
            DispatchQueue.main.async {
                self.photos = sortedURLs
            }
        }
    }
    
    /// ディスク上に保存するときに、正しい creationDate がつくようにする例
    func importPhotoData(_ data: Data, fileExtension: String) -> URL? {
        let filename = UUID().uuidString + "." + fileExtension
        let destURL = docsDir.appendingPathComponent(filename)
        do {
            try data.write(to: destURL)
            // iOSでは書き込み時点のファイル作成日時が自動で付くので、
            // ここで特に修正しなくてもOK。ただし、日付を明示的に変更したい場合は下記例参照。
            return destURL
        } catch {
            print("写真保存エラー: \(error)")
            return nil
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
