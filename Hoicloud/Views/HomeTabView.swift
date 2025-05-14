//
//  HomeView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/29/25.
//

import SwiftUI
import PhotosUI

struct HomeTabView: View {
    @EnvironmentObject var tabRouter: TabRouter
    
    @Binding var showConfiguration: Bool
    @Binding var showAddItemSheet: Bool
    
    @State private var isSelecting = false
    @State private var selectedItems: [Metadata] = []
    @State private var sortedPhotos: [Metadata] = []

    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    @ObservedObject private var storageApi = StorageApi.shared
    @ObservedObject private var downloadProgress = Progress.downloads
    
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
                        ForEach(sortedPhotos) { photo in
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
                    sortPhotos()
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
            .onChange(of: storageApi.photos) {
                sortPhotos()
            }
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // delete button
                        Button(action: deleteAction) {
                            Label("Delete", systemImage: "trash")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // download button
                        Button(action: downloadAction) {
                            Label("Download", systemImage: "square.and.arrow.down")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // select button
                        Button(action: finishSelecting) {
                            Text("Cancel")
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // select button
                        Button(action: startSelecting) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // add button
                        Button(action: startAddItem) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // config button
                        Button(action: startConfiguration) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
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
            isSelecting: $isSelecting,
            destination: {
                FullImageView(photo: photo, photos: sortedPhotos)
            }
        )
    }
    
    private func sortPhotos() {
        DispatchQueue.global(qos: .userInitiated).async {
            let sorted = self.storageApi.photos.values.sorted { left, right in
                let s1 = left.created ?? left.uploaded ?? Date.distantPast.ISO8601Format()
                let s2 = right.created ?? right.uploaded ?? Date.distantPast.ISO8601Format()
                return s2 < s1
            }
            
            DispatchQueue.main.async {
                self.sortedPhotos = sorted
            }
        }
    }
    
    private func downloadAction() {
        tabRouter.selectedTab = .downloads
        Task {
            for photo in selectedItems {
                guard let filekey = photo.filekey else { continue }
                downloadProgress.start(id: filekey)
            }
            for photo in selectedItems {
                guard let filekey = photo.filekey else { continue }
                print("Downloading: \(filekey)")
                downloadProgress.update(id: filekey, rate: 0.1)
                if let data = await storageApi.getFullImageData(filekey: filekey) {
                    downloadProgress.update(id: filekey, rate: 0.80)
                    if let image = UIImage(data: data) {
                        downloadProgress.update(id: filekey, rate: 0.90)
                        ImageSaver().writeToPhotoAlbum(image: image)
                    }
                }
                downloadProgress.complete(id: filekey)
            }
        }
        finishSelecting()
    }
    
    private func deleteAction() {
        Task {
            for photo in selectedItems {
                await storageApi.deleteFile(photo: photo)
            }
            finishSelecting()
        }
    }
    
    private func startSelecting() {
        selectedItems = []
        isSelecting = true
    }
    
    private func finishSelecting() {
        isSelecting = false
    }
    
    private func startAddItem() {
        showAddItemSheet = true
    }
    
    private func startConfiguration() {
        showConfiguration = true
    }
}
