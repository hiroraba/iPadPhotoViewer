//
//  PhotoPicker.swift
//  iPadPhotoViewer
//  
//  Created by matsuohiroki on 2025/05/31.
//  
//

import SwiftUI
import PhotosUI
import Photos

struct PhotoPicker: UIViewControllerRepresentable {
    /// 複数のPHAssetを返すクロージャに変更
    var completion: ([PHAsset]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 0       // 0 = 制限なし（複数選択可）
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            // 選択されたすべてのPHAssetを取得
            let assetIds = results.compactMap { $0.assetIdentifier }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
            var picked: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                picked.append(asset)
            }
            // クロージャに配列で渡す
            parent.completion(picked)
        }
    }
}
