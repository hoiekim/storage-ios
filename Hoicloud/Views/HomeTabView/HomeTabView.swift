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
    @State private var searchText = ""
    @State private var selectedLabels: [String] = []
    @State private var sortedPhotos: [Metadata] = []
    @State private var positionID: String? = "photo_0"
    @State private var sortedPhotosVersion: Int = 0
    
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
    
    var body: some View {
        NavigationView {
            renderScrollView()
                .coordinateSpace(name: "scroll")
                .frame(maxWidth: .infinity)
                .navigationTitle("Hoicloud")
                .onPreferenceChange(VisibleIndexKey.self) { indices in
                    onVisibleIndicesChange(indices)
                }
                .toolbar { renderToolbar() }
                .navigationViewStyle(StackNavigationViewStyle())
        }
        .onChange(of: storageApi.photos) { sortPhotos() }
        .onChange(of: searchText) { sortPhotos() }
        .onChange(of: selectedLabels) { sortPhotos() }
    }
    
    @State private var sortTask: Task<Void, Never>?
    
    func sortPhotos() {
        sortTask?.cancel()
        sortTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            
            let photosArray = if selectedLabels.isEmpty {
                Array(storageApi.photos.values)
            } else {
                storageApi.photos.values.filter { photo in
                    if let labels = storageApi.labels[photo.id] {
                        return Set(labels).intersection(Set(selectedLabels)).count > 0
                    }
                    return false
                }
            }
            
            if searchText.isEmpty {
                let sorted = photosArray.sorted { left, right in
                    let s1 = left.created ?? left.uploaded ?? Date.distantPast.ISO8601Format()
                    let s2 = right.created ?? right.uploaded ?? Date.distantPast.ISO8601Format()
                    return s2 < s1
                }
                
                DispatchQueue.main.async {
                    self.sortedPhotos = sorted
                    self.sortedPhotosVersion += 1
                    self.onVisibleIndicesChange(Set(0..<min(15, sorted.count)))
                }
            } else {
                // Sort all photos by match score based on labels
                let sorted = photosArray.map { photo in
                    var bestScore = 0.0
                    if let labels = storageApi.labels[photo.id] {
                        var searchPool = Array(labels)
                        searchPool.append(photo.mime_type)
                        for label in searchPool {
                            let score = getMatchScore(string: label, to: searchText)
                            bestScore = max(bestScore, score)
                            
                            if label.lowercased().contains(searchText.lowercased()) {
                                bestScore = max(bestScore, 0.9)
                            }
                        }
                    }
                    return (photo, bestScore)
                }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
                
                DispatchQueue.main.async {
                    self.sortedPhotos = sorted
                    self.sortedPhotosVersion += 1
                    self.onVisibleIndicesChange(Set(0..<min(15, sorted.count)))
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderScrollView() -> some View {
        let scrollView = ScrollView {
            LabelsView(selectedLabels: $selectedLabels)
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(sortedPhotos.enumerated()), id: \.1.id) { index, photo in
                    renderStack(photo: photo, index: index)
                }
            }
            .id(sortedPhotosVersion)
            if sortedPhotos.isEmpty && !searchText.isEmpty {
                Text("No photos match your search")
                    .multilineTextAlignment(.center)
                    .padding(.top, 30.0)
                    .padding(.bottom, 10.0)
                    .padding(.leading, 10.0)
                    .padding(.trailing, 10.0)
                    .id("photo_0")
            } else if numberOfPhotos == 0 {
                Text("Your cloud is empty")
                    .multilineTextAlignment(.center)
                    .padding(.top, 30.0)
                    .padding(.bottom, 10.0)
                    .padding(.leading, 10.0)
                    .padding(.trailing, 10.0)
                    .id("photo_0")
            }
        }
        .refreshable {
            storageApi.downloadMetadata()
            storageApi.downloadLabels()
        }
        
        if sortedPhotos.isEmpty {
            scrollView
        } else {
            scrollView
                .scrollPosition(id: $positionID, anchor: .top)
                .defaultScrollAnchor(.top)
                .searchable(text: $searchText, placement: .automatic)
        }
    }
    
    @ViewBuilder
    private func renderStack(photo: Metadata, index: Int) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let tileHeight = screenWidth / 3
        
        GeometryReader { _ in
            ImageStackView(
                photo: photo,
                selectedItems: $selectedItems,
                isSelecting: $isSelecting,
                destination: {
                    FullImageView(photo: photo, photos: sortedPhotos)
                }
            )
            .preference(key: VisibleIndexKey.self, value: [index])
        }
        .frame(height: tileHeight)
        .id("\(sortedPhotosVersion)_photo_\(index)")
    }
    
    @ToolbarContentBuilder
    private func renderToolbar() -> some ToolbarContent {
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
                // select cancel button
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
    
    @State private var prefetchWorkItem: DispatchWorkItem?
    
    private func onVisibleIndicesChange(_ indices: Set<Int>) {
        prefetchWorkItem?.cancel()
        let work = DispatchWorkItem {
            let margin = 30
            guard let minIndex = indices.min(), let maxIndex = indices.max() else { return }

            let start = max(minIndex - margin, 0)
            let end = min(maxIndex + margin, sortedPhotos.count - 1)

            for (index, photo) in sortedPhotos.enumerated() {
                guard let filekey = photo.filekey else { continue }
                if index >= start && index <= end {
                    storageApi.downloadThumbnail(for: filekey)
                }
            }
        }
        prefetchWorkItem = work
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}

struct VisibleIndexKey: PreferenceKey {
    static var defaultValue: Set<Int> = []
    
    static func reduce(value: inout Set<Int>, nextValue: () -> Set<Int>) {
        value.formUnion(nextValue())
    }
}
