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
    
    @State private var showConfiguration = false
    @State private var showAddItemSheet = false
    @State private var isSelecting = false
    @State private var selectedItems: [Metadata] = []
    @State private var showDownloadConfirmation = false
    @State private var sortedPhotos: [Metadata] = []

    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    @ObservedObject private var storageApi = StorageApi.shared
    @ObservedObject private var uploadProgress = Progress.uploads
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
            .onChange(of: storageApi.photos) {
                sortPhotos()
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
                        // delete button
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
                        // download button
                        Button(action: {
                            tabRouter.selectedTab = .downloads
                            Task {
                                for photo in selectedItems {
                                    downloadProgress.start(id: photo.filekey)
                                }
                                for photo in selectedItems {
                                    print("Downloading: \(photo.filekey)")
                                    downloadProgress.update(id: photo.filekey, rate: 0.1)
                                    if let data = await storageApi.getFullImageData(filekey: photo.filekey) {
                                        downloadProgress.update(id: photo.filekey, rate: 0.60)
                                        if let image = UIImage(data: data) {
                                            downloadProgress.update(id: photo.filekey, rate: 0.90)
                                            ImageSaver().writeToPhotoAlbum(image: image)
                                        }
                                    }
                                    downloadProgress.complete(id: photo.filekey)
                                }
                            }
                            isSelecting = false
                        }) {
                            Label("Download", systemImage: "square.and.arrow.down")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // select button
                        Button(action: {
                            isSelecting = false
                        }) {
                            Text("Cancel")
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // add button
                        Button(action: {
                            showAddItemSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // select button
                        Button(action: {
                            selectedItems = []
                            isSelecting = true
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // config button
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
            isSelecting: $isSelecting,
            destination: {
                FullImageView(photo: photo, photos: sortedPhotos)
            }
        )
    }
    
    private func sortPhotos() {
        DispatchQueue.global(qos: .userInitiated).async {
            let sorted = self.storageApi.photos.values.sorted { left, right in
                let s1 = left.created ?? left.uploaded
                let s2 = right.created ?? right.uploaded
                return s2 < s1
            }
            
            DispatchQueue.main.async {
                self.sortedPhotos = sorted
            }
        }
    }
}
