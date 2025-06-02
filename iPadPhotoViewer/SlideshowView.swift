//
// SlideshowView.swift
//  iPadPhotoViewer
//
//  Created by matsuohiroki on 2025/05/31.
//
//

import SwiftUI
import Photos

struct SlideshowView: View {
    @ObservedObject var photoManager: PhotoManager

    @State private var playQueue: [URL] = []
    @State private var currentPhoto: URL?
    @State private var isPlaying = true
    @State private var showMenu = false
    @State private var showAlertOnResume = false

    @State private var currentText: String = ""
    @State private var startDate: Date = Date()

    @Environment(\.dismiss) private var dismiss
    private let initialIndex: Int

    private var texts: [String] {
        // texts.txt を読み込んで一行ごとに配列化
        if let fileURL = Bundle.main.url(forResource: "text", withExtension: "txt"),
           let content = try? String(contentsOf: fileURL) {
            let lines = content
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !lines.isEmpty {
                return lines
            }
        }
        // texts.txt が見つからないか空の場合のデフォルト文字列
        return [
            "デフォルトのセリフ1", "デフォルトのセリフ2", "デフォルトのセリフ3"
        ]
    }

    init(photoManager: PhotoManager, startIndex: Int) {
        self.photoManager = photoManager
        self.initialIndex = startIndex
    }

    var body: some View {
        VStack(spacing: 0) {
            // 画像、テキスト、メニュー、ゲージを一つのZStackで重ねる
            ZStack(alignment: .bottom) {
                // ── 背景: 画像部分 ──
                if let url = currentPhoto {
                    Image(uiImage: UIImage(contentsOfFile: url.path)!)
                        .resizable()
                        .scaledToFit()
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .ignoresSafeArea(edges: .horizontal)
                        .id(url)
                        .onTapGesture {
                            if !showMenu {
                                isPlaying = false
                                withAnimation { showMenu = true }
                            }
                        }
                } else {
                    Color.black.ignoresSafeArea()
                    Text("No photos")
                        .foregroundColor(.white)
                        .font(.title)
                }

                // ── 下部: タイマーゲージ ──
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                        TimelineView(.animation) { context in
                            let elapsed = context.date.timeIntervalSince(startDate)
                            let fraction = max(0, min(1, 1 - elapsed / 10))
                            Color.green
                                .frame(width: proxy.size.width * CGFloat(fraction), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .background(Color.clear)

                // ── 右上: ランダムテキスト ──
                VStack {
                    HStack {
                        Spacer()
                        Text(currentText)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(.top, 30)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }

                // ── メニューオーバーレイ ──
                if showMenu {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { showMenu = false }
                            }
                        VStack(spacing: 30) {
                            Button(action: {
                                withAnimation { showMenu = false }
                                isPlaying = true
                            }) {
                                Label("再開", systemImage: "play.fill")
                            }
                            Button(action: {
                                withAnimation { showMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismiss()
                                }
                            }) {
                                Label("終了", systemImage: "xmark.circle.fill")
                            }
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBar(hidden: true)
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying && !showMenu else { return }
            next()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            isPlaying = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !isPlaying {
                showAlertOnResume = true
            }
        }
        .alert("スライドショーを再開しますか？", isPresented: $showAlertOnResume) {
            Button("はい") {
                isPlaying = true
                showMenu = false
            }
            Button("いいえ", role: .cancel) { }
        }
        .onAppear {
            resetQueue(withStartIndex: initialIndex)
            next()
            startDate = Date()
            currentText = texts.randomElement() ?? ""
        }
    }

    // MARK: - ランダムキュー生成

    private func resetQueue(withStartIndex startIndex: Int) {
        let urls = photoManager.photos
        guard !urls.isEmpty,
              startIndex >= 0, startIndex < urls.count else {
            playQueue = []
            currentPhoto = nil
            return
        }
        var remaining = urls
        let firstURL = remaining.remove(at: startIndex)
        remaining.shuffle()
        playQueue = [firstURL] + remaining
    }

    // MARK: - 次の写真を表示 & テキスト更新

    private func next() {
        guard !playQueue.isEmpty else {
            resetQueue(withStartIndex: 0)
            return
        }
        let nextURL = playQueue.removeFirst()
        withAnimation {
            currentPhoto = nextURL
        }
        startDate = Date()
        currentText = texts.randomElement() ?? ""
    }
}
