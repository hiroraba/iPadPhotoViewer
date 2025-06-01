//
//  PhotoDetailView.swift
//  iPadPhotoViewer
//  
//  Created by matsuohiroki on 2025/05/31.
//  
//

import SwiftUI

struct PhotoDetailView: View {
    @ObservedObject var photoManager: PhotoManager
    @State private var currentIndex: Int

    // スライドショーモーダル表示用
    @State private var showSlideshow = false

    // 前/次へ移動時に使う PresentationMode
    @Environment(\.presentationMode) private var presentationMode

    init(photoManager: PhotoManager, currentIndex: Int) {
        self.photoManager = photoManager
        self._currentIndex = State(initialValue: currentIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 画面上部: フルスクリーンで写真を表示
            GeometryReader { geo in
                let url = photoManager.photos[currentIndex]
                Image(uiImage: UIImage(contentsOfFile: url.path)!)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.black)
            }
            .edgesIgnoringSafeArea(.top)

            // 画面下部: 操作ボタンを HStack で配置
            HStack(spacing: 40) {
                // 「前へ」ボタン
                Button(action: {
                    movePrevious()
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                .disabled(currentIndex == 0) // 最初の写真なら押せない

                // 「スライドショー」ボタン
                Button(action: {
                    showSlideshow = true
                }) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                }

                // 「次へ」ボタン
                Button(action: {
                    moveNext()
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                .disabled(currentIndex == photoManager.photos.count - 1) // 最後の写真なら押せない
                
                Button(action: {
                    deleteCurrentPhoto()
                }) {
                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarTitleDisplayMode(.inline)
        // フルスクリーンモーダルで SlideshowView を起動
        .fullScreenCover(isPresented: $showSlideshow) {
            SlideshowView(
                photoManager: photoManager,
                startIndex: currentIndex
            )
        }
    }

    // MARK: - 前/次へロジック

    private func movePrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func moveNext() {
        guard currentIndex < photoManager.photos.count - 1 else { return }
        currentIndex += 1
    }
    
    private func deleteCurrentPhoto() {
        // ① PhotoManager でファイル削除 & 配列更新
        photoManager.deletePhoto(at: currentIndex)

        // ② 写真が 0 枚になったらこの画面を閉じる
        if photoManager.photos.isEmpty {
            presentationMode.wrappedValue.dismiss()
        } else {
            // ③ 残りの写真がある場合、currentIndex を範囲内に調整
            if currentIndex >= photoManager.photos.count {
                currentIndex = photoManager.photos.count - 1
            }
        }
    }
}
