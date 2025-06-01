//
//  iPadPhotoViewerApp.swift
//  iPadPhotoViewer
//  
//  Created by matsuohiroki on 2025/05/30.
//  
//

import SwiftUI

@main
struct iPadPhotoViewerApp: App {
    // PhotoManager をアプリ全体で共有
    @StateObject private var photoManager = PhotoManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoManager)
        }
    }
}
