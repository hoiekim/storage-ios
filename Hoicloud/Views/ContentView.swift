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
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    
    @StateObject private var tabRouter = TabRouter()
    @State var showConfiguration = false
    @State var showAddItemSheet = false
    
    @ObservedObject private var storageApi = StorageApi.shared
    
    var anyOfMultiple: [String] {[
        apiHost,
        apiKey,
        showConfiguration.description
    ]}
    
    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            HomeTabView(
                showConfiguration: $showConfiguration,
                showAddItemSheet: $showAddItemSheet
            )
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            UploadProgressTabView(
                showConfiguration: $showConfiguration,
                showAddItemSheet: $showAddItemSheet,
            )
            .tabItem {
                Label("Uploads", systemImage: "arrow.up.circle")
            }
            .tag(Tab.uploads)
            DownloadProgressTabView(
                showConfiguration: $showConfiguration,
                showAddItemSheet: $showAddItemSheet,
            )
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            .tag(Tab.downloads)
        }
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView(show: $showConfiguration)
        }
        .sheet(isPresented: $showAddItemSheet) {
            ImagePickerView(show: $showAddItemSheet)
        }
        .environmentObject(tabRouter)
        .preferredColorScheme(.dark)
        .onChange(of: anyOfMultiple) {
            Task {
                if await storageApi.healthCheck() {
                    storageApi.downloadMetadata()
                    storageApi.downloadLabels()
                } else {
                    showConfiguration = true
                }
            }
        }
        .onAppear {
            if apiHost.isEmpty || apiKey.isEmpty {
                showConfiguration = true
            } else {
                Task {
                    if await storageApi.healthCheck() {
                        storageApi.downloadMetadata()
                        storageApi.downloadLabels()
                    } else {
                        showConfiguration = true
                    }
                    
                    try? await Task.sleep(for: .seconds(10))
                    await SyncUtil.shared.uploadMissingLabels()
                }
            }
            storageApi.tusUtil.resume()
        }
    }
    
    private func startConfiguration() {
        showConfiguration = true
    }
}

#Preview {
    ContentView()
}
