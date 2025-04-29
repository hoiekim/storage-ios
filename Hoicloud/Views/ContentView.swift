//
//  ContentView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            UploadProgressView()
                .tabItem {
                    Label("Uploads", systemImage: "arrow.trianglehead.2.clockwise")
                }
        }
    }
}

#Preview {
    ContentView()
}
