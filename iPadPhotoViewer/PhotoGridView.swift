//
//  PhotoGridView.swift
//  iPadPhotoViewer
//
//  Created by assistant on 2025/05/31.
//

import SwiftUI

struct PhotoGridView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var showingSettings = false
    @State private var showingPicker = false

    // グリッドのセルサイズ（正方形）
    let cellSize: CGFloat = 100

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: cellSize), spacing: 5)],
                    spacing: 5
                ) {
                    ForEach(photoManager.photos.indices, id: \.self) { index in
                        let url = photoManager.photos[index]
                        NavigationLink(destination: PhotoDetailView(photoManager: photoManager, currentIndex: index)) {
                            ThumbnailView(url: url, size: CGSize(width: cellSize, height: cellSize))
                                .frame(width: cellSize, height: cellSize)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(5)
            }
            .navigationTitle("写真一覧")
            .toolbar {
                // 右上に設定画面への遷移ボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                
                // 右上に「＋」ボタン（写真読み込み用）
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                PhotoPicker { assets in
                    // 複数選択された時は import() を呼ぶ
                    let group = DispatchGroup()
                    for asset in assets {
                        group.enter()
                        photoManager.import(asset: asset) { _ in
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        photoManager.loadPhotos()
                        showingPicker = false
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// ── サムネイルを表示するカスタム View ──
struct ThumbnailView: View {
    @StateObject private var loader: ImageLoader
    private let placeholder = Color.gray.opacity(0.3)

    init(url: URL, size: CGSize) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url, thumbnailSize: size))
    }

    var body: some View {
        // ロード中はグレー背景、読み込まれたらサムネイルを表示
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipped()
    }
}
