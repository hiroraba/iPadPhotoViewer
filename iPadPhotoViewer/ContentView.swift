//
//  ContentView.swift
//  iPadPhotoViewer
//
//  Created by matsuohiroki on 2025/05/30.
//
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var photoManager: PhotoManager

    var body: some View {
        // PhotoGridView が NavigationView を内包しているので、
        // そのまま呼び出せばOK
        PhotoGridView()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
