//
//  ContentView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI
import PhotosUI

class TabRouter: ObservableObject {
    @Published var selectedTab: Tab = .home
}

enum Tab {
    case home, uploads, downloads
}

struct ContentView: View {
    @StateObject private var tabRouter = TabRouter()
    
    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            ProgressTabView(
                progress: Progress.uploads,
                title: "Uploads",
            )
            .tabItem {
                Label("Uploads", systemImage: "arrow.up.circle")
            }
            .tag(Tab.uploads)
            ProgressTabView(
                progress: Progress.downloads,
                title: "Downloads",
            )
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            .tag(Tab.downloads)
        }
        .environmentObject(tabRouter)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
