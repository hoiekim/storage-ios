//
//  ContentView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var showFullScreen = false
    @State private var showConfiguration = false
    @State private var showAddItemSheet = false
    @State private var isSelecting = false
    @State private var selectedItems: [Metadata] = []
    @State private var selectedItem: Metadata? = nil
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    @StateObject private var storageApi = StorageApi()
    @StateObject private var progress = Progress()
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var anyOfMultiple: [String] {[apiHost, apiKey]}
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1) {
                            ForEach(storageApi.photos) { photo in
                                renderStack(photo)
                            }
                        }
                    }
                    .navigationTitle("Hoicloud")
                    .onAppear {
                        if apiHost.isEmpty || apiKey.isEmpty {
                            showConfiguration = true
                        } else {
                            storageApi.fetchMetadata()
                        }
                    }
                    .onChange(of: anyOfMultiple) {
                        storageApi.fetchMetadata()
                    }
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullImageView(
                            isPresented: $showFullScreen,
                            storageApi: storageApi,
                            selectedItem: $selectedItem
                        )
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
                                        for photo in selectedItems {
                                            progress.start(id: photo.filekey)
                                        }
                                        for photo in selectedItems {
                                            print("Downloading: \(photo.filekey)")
                                            if let data = await storageApi.getFullImageData(filekey: photo.filekey),
                                               let image = UIImage(data: data) {
                                                ImageSaver().writeToPhotoAlbum(image: image)
                                            }
                                            progress.complete(id: photo.filekey)
                                        }
                                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
                                        for photo in selectedItems {
                                            progress.remove(id: photo.filekey)
                                        }
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
                        ImagePickerView(
                            storageApi: storageApi,
                            progress: progress,
                            show: $showAddItemSheet
                        )
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showAddItemSheet = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(.blue)
                                    .clipShape(Circle())
                                    .shadow(
                                        color: .black,
                                        radius: 15,
                                        x: 5,
                                        y: 10
                                    )
                            }
                            .padding()
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            
            VStack {
                if !progress.isEmpty() {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress.rate())
                        }
                        .cornerRadius(2)
                    }
                    .frame(height: 4)
                    .padding(.horizontal)
                    .animation(.linear, value: progress.rate())
                    Spacer()
                }
            }
        }
        .refreshable {
            print("refreshing")
            storageApi.fetchMetadata()
        }
    }
    
    @ViewBuilder
    private func renderStack(_ photo: Metadata) -> some View {
        ImageStackView(
            storageApi: storageApi,
            photo: photo,
            showFullScreen: $showFullScreen,
            selectedItem: $selectedItem,
            selectedItems: $selectedItems,
            isSelecting: $isSelecting
        )
    }
}

#Preview {
    ContentView()
}
