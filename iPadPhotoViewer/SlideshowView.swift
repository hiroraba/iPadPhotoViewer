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

    // ── ここから変更 ──

    /// 現在画面に表示しているテキスト
    @State private var currentText: String = ""

    /// バンドル内の texts.txt を読み込み、一行ごとに配列化
    private var texts: [String] {
        // Bundle.main に「texts.txt」がある前提
        guard let fileURL = Bundle.main.url(forResource: "text", withExtension: "txt"),
              let content = try? String(contentsOf: fileURL) else {
            return []
        }
        return content
            .components(separatedBy: .newlines)                            // 改行で分割
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }   // 前後空白を削除
            .filter { !$0.isEmpty }                                       // 空行を除去
    }
    // ── ここまで変更 ──

    // スライドショー進行管理用: 再生開始時刻を保持
    @State private var startDate: Date = Date()

    // フルスクリーンを閉じる
    @Environment(\.dismiss) private var dismiss

    // 再生開始時に使用する初期インデックス
    private let initialIndex: Int

    init(photoManager: PhotoManager, startIndex: Int) {
        self.photoManager = photoManager
        self.initialIndex = startIndex
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ── 背景: 現在の写真（またはプレースホルダー） ──
            if let url = currentPhoto {
                Image(uiImage: UIImage(contentsOfFile: url.path)!)
                    .resizable()
                    .scaledToFill()                          // Fill メソッドに変更
                                        .clipped()                                // はみ出した部分を切り落とす
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.black)                  // 背景を黒にして余白を隠す
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .id(url)
                    // タップで一時停止 → メニュー表示
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

            // ── 左上: 黒背景＋白文字でランダムテキスト表示 ──
            Text(currentText)
                .font(.largeTitle)
                .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(.top, 50)       // ステータスバー分くらい余白を空ける
                            .padding(.trailing, 16)
                            .padding(.leading, 16)

            // ── メニューオーバーレイ ──
            if showMenu {
                Color.black.opacity(0.6).ignoresSafeArea()
                ZStack {
                    // メニュー背景をタップで閉じる
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { showMenu = false }
                        }
                    VStack(spacing: 30) {
                        // 再開ボタン
                        Button(action: {
                            withAnimation { showMenu = false }
                            isPlaying = true
                        }) {
                            Label("再開", systemImage: "play.fill")
                        }

                        // 終了ボタン
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

            // ── 画面下部: タイマーゲージ（TimelineView） ──
            VStack {
                Spacer()
                // 緑バー: 再生開始時刻からの経過時間に応じて幅を縮める
                GeometryReader { proxy in
                    TimelineView(.animation) { context in
                        let elapsed = context.date.timeIntervalSince(startDate)
                        let fraction = max(0, min(1, 1 - elapsed / 10))
                        Color.green
                            .frame(width: proxy.size.width * CGFloat(fraction), height: 4)
                            .ignoresSafeArea(.all, edges: .horizontal)
                    }
                }
                .frame(height: 4)
            }
            .ignoresSafeArea(.all, edges: .horizontal)
        }
        // ── ステータスバーを隠す ──
        .statusBar(hidden: true)
        // タイマー: 10秒経過で next() を呼ぶ
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying && !showMenu else { return }
            next()
        }
        // バックグラウンドで停止
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            isPlaying = false
        }
        // フォアグラウンド復帰で再開確認ダイアログ
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
        // 最初にキューを作成し初期写真をセット
        .onAppear {
            resetQueue(withStartIndex: initialIndex)
            next()                     // currentPhoto をセット
            startDate = Date()         // タイマーゲージの基準日時をリセット
            // ランダムテキストを初期設定
            currentText = texts.randomElement() ?? ""
        }
        .ignoresSafeArea(.all)
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
        // 指定インデックスの写真を先頭に取り出し
        var remaining = urls
        let firstURL = remaining.remove(at: startIndex)
        remaining.shuffle()
        playQueue = [firstURL] + remaining
        // ゲージは next() で初期表示と同時にリセットされる
    }

    // MARK: - 次の写真を表示 & ランダムテキスト更新

    private func next() {
        guard !playQueue.isEmpty else {
            // キューが空なら再度リセット
            resetQueue(withStartIndex: 0)
            return
        }
        // キュー先頭を currentPhoto にセットしてキューから除去
        let nextURL = playQueue.removeFirst()
        withAnimation {
            currentPhoto = nextURL
        }
        // 写真切り替え時にタイマーゲージを再スタート
        startDate = Date()
        // ランダムで次のテキストを設定
        currentText = texts.randomElement() ?? ""
    }
}
