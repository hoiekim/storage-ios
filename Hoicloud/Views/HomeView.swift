//
//  HomeView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/29/25.
//

import SwiftUI
import PhotosUI

struct HomeView: View {
    @State private var showConfiguration = false
    @State private var showAddItemSheet = false
    @State private var isSelecting = false
    @State private var selectedItems: [Metadata] = []

    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    @StateObject private var storageApi = StorageApi.shared
    @StateObject private var progress = Progress.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var numberOfPhotos: Int { storageApi.photos.count }
    
    var anyOfMultiple: [String] {[apiHost, apiKey, showConfiguration.description]}
    
    var body: some View {
        NavigationView {
            ScrollView {
                if numberOfPhotos == 0 {
                    Text("Your cloud is empty")
                        .multilineTextAlignment(.center)
                        .padding(.top, 30.0)
                        .padding(.bottom, 10.0)
                        .padding(.leading, 10.0)
                        .padding(.trailing, 10.0)
                } else {
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(storageApi.photos) { photo in
                            renderStack(photo)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Hoicloud")
            .onAppear {
                if apiHost.isEmpty || apiKey.isEmpty {
                    showConfiguration = true
                } else {
                    Task {
                        if await storageApi.healthCheck() {
                            storageApi.downloadMetadata()
                        } else {
                            showConfiguration = true
                        }
                    }
                }
            }
            .onChange(of: anyOfMultiple) {
                Task {
                    if await storageApi.healthCheck() {
                        storageApi.downloadMetadata()
                    } else {
                        showConfiguration = true
                    }
                }
            }
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                for photo in selectedItems {
                                    await storageApi.deleteFile(photo: photo)
                                }
                                isSelecting = false
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
//                                for photo in selectedItems {
//                                    progress.start(id: photo.filekey)
//                                }
                                for photo in selectedItems {
                                    print("Downloading: \(photo.filekey)")
                                    if let data = await storageApi.getFullImageData(filekey: photo.filekey),
                                       let image = UIImage(data: data) {
                                        ImageSaver().writeToPhotoAlbum(image: image)
                                    }
//                                    progress.complete(id: photo.filekey)
                                }
//                                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
//                                for photo in selectedItems {
//                                    progress.remove(id: photo.filekey)
//                                }
                                isSelecting = false
                            }
                        }) {
                            Label("Download", systemImage: "square.and.arrow.down")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            isSelecting = false
                        }) {
                            Text("Cancel")
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showAddItemSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            selectedItems = []
                            isSelecting = true
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showConfiguration = true
                        }) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showConfiguration) {
                ConfigurationView(show: $showConfiguration)
            }
            .sheet(isPresented: $showAddItemSheet) {
                ImagePickerView(show: $showAddItemSheet)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .preferredColorScheme(.dark)
        }
        .refreshable {
            print("refreshing")
            storageApi.downloadMetadata()
        }
    }
    
    @ViewBuilder
    private func renderStack(_ photo: Metadata) -> some View {
        ImageStackView(
            photo: photo,
            selectedItems: $selectedItems,
            isSelecting: $isSelecting
        )
    }
}
