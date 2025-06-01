//
//  ImageCache.swift
//  iPadPhotoViewer
//  
//  Created by matsuohiroki on 2025/06/01.
//  
//

import SwiftUI
import Combine

// ── ImageCache ──
// NSCache を使って「URL → UIImage のサムネイル」をキャッシュする
final class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insertImage(_ image: UIImage?, for url: URL) {
        guard let image = image else { return }
        cache.setObject(image, forKey: url as NSURL)
    }
}

// ── ImageLoader ──
// ファイルURL からサムネイルを生成し、キャッシュをチェックして Async に読み込む
final class ImageLoader: ObservableObject {
    @Published var image: UIImage? = nil

    private var cancellable: AnyCancellable?
    private let url: URL
    private let thumbnailSize: CGSize

    init(url: URL, thumbnailSize: CGSize) {
        self.url = url
        self.thumbnailSize = thumbnailSize
        load()
    }

    private func load() {
        // まずキャッシュをチェック
        if let cached = ImageCache.shared.image(for: url) {
            self.image = cached
            return
        }

        // キャッシュになければ非同期でサムネイルを生成
        cancellable = Just(url)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .map { url -> UIImage? in
                // CGImageSource を使って縮小したサムネイルを生成
                guard let dataProvider = CGDataProvider(url: url as CFURL),
                      let cgImageSource = CGImageSourceCreateWithDataProvider(dataProvider, nil) else {
                    return nil
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(Int(self.thumbnailSize.width), Int(self.thumbnailSize.height))
                ]
                guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(cgImageSource, 0, options as CFDictionary) else {
                    return nil
                }
                return UIImage(cgImage: cgThumb)
            }
            .handleEvents(receiveOutput: { [weak self] thumb in
                // キャッシュに保存
                guard let thumb = thumb else { return }
                guard let self = self else { return }
                ImageCache.shared.insertImage(thumb, for: self.url)
            })
            .receive(on: DispatchQueue.main)
            .assign(to: \.image, on: self)
    }

    deinit {
        cancellable?.cancel()
    }
}
