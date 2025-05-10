//
//  FullImageView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/26/24.
//

import SwiftUI
import AVKit
import Photos

func nextElement<T: Equatable>(after element: T, in array: [T]) -> T? {
    guard let currentIndex = array.firstIndex(of: element) else {
        return nil
    }
    let nextIndex = currentIndex + 1
    return nextIndex < array.count ? array[nextIndex] : nil
}

func previousElement<T: Equatable>(before element: T, in array: [T]) -> T? {
    guard let currentIndex = array.firstIndex(of: element) else {
        return nil
    }
    let previousIndex = currentIndex - 1
    return previousIndex >= 0 ? array[previousIndex] : nil
}

// Protocol to abstract common functionality between Metadata and PHAsset
protocol MediaItem {
    var id: String { get }
    var filename: String { get }
    var mimeType: String { get }
    func getThumbnail(completion: @escaping (UIImage?) -> Void)
    func getFullImage(completion: @escaping (UIImage?) -> Void)
    func getVideoURL(completion: @escaping (URL?) -> Void)
}

// Wrapper for Metadata to conform to MediaItem
class MetadataItem: MediaItem, Identifiable, Equatable {
    let metadata: Metadata
    private let storageApi = StorageApi.shared
    
    init(metadata: Metadata) {
        self.metadata = metadata
    }
    
    var id: String {
        return metadata.filekey ?? metadata.item_id
    }
    
    var filename: String {
        return metadata.filename
    }
    
    var mimeType: String {
        return metadata.mime_type
    }
    
    func getThumbnail(completion: @escaping (UIImage?) -> Void) {
        guard let filekey = metadata.filekey else { return completion(nil) }
        if let thumbnail = storageApi.thumbnails[filekey] {
            completion(thumbnail)
        } else {
            completion(nil)
        }
    }
    
    func getFullImage(completion: @escaping (UIImage?) -> Void) {
        guard let filekey = metadata.filekey else { return completion(nil) }
        Task {
            if let data = await storageApi.getFullImageData(filekey: filekey) {
                let image = UIImage(data: data)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func getVideoURL(completion: @escaping (URL?) -> Void) {
        guard let filekey = metadata.filekey else { return completion(nil) }
        let request = storageApi.getFullImageRequest(filekey: filekey)
        completion(request?.url)
    }
    
    static func == (lhs: MetadataItem, rhs: MetadataItem) -> Bool {
        return lhs.metadata.filekey == rhs.metadata.filekey
    }
}

// Wrapper for PHAsset to conform to MediaItem
class AssetItem: MediaItem, Identifiable, Equatable {
    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
    }
    
    var id: String {
        return asset.localIdentifier
    }
    
    var filename: String {
        let resource = PHAssetResource.assetResources(for: asset).first
        return resource?.originalFilename ?? "Unknown"
    }
    
    var mimeType: String {
        switch asset.mediaType {
        case .image:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        case .audio:
            return "audio/mp4"
        default:
            return "application/octet-stream"
        }
    }
    
    func getThumbnail(completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    func getFullImage(completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    func getVideoURL(completion: @escaping (URL?) -> Void) {
        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    DispatchQueue.main.async {
                        completion(urlAsset.url)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            completion(nil)
        }
    }
    
    static func == (lhs: AssetItem, rhs: AssetItem) -> Bool {
        return lhs.asset.localIdentifier == rhs.asset.localIdentifier
    }
}

struct FullImageView: View {
    @StateObject private var storageApi = StorageApi.shared
    
    @State private var metadataItem: MetadataItem?
    @State private var metadataItems: [MetadataItem] = []
    
    @State private var assetItem: AssetItem?
    @State private var assetItems: [AssetItem] = []
    
    @State private var isAsset = false
    
    @State var showMetadata = false
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    
    // State for TabView
    @State private var selectedIndex: Int = 0
    @State private var mediaCache: [Int: MediaCache] = [:]
    
    init(photo: Metadata, photos: [Metadata] = []) {
        self._metadataItem = State(initialValue: MetadataItem(metadata: photo))
        self._metadataItems = State(initialValue: photos.map { MetadataItem(metadata: $0) })
        self._isAsset = State(initialValue: false)
        
        // Find the index of the current item
        if let index = photos.firstIndex(where: { $0.item_id == photo.item_id }) {
            self._selectedIndex = State(initialValue: index)
        }
    }
    
    init(asset: PHAsset, assets: [PHAsset] = []) {
        self._assetItem = State(initialValue: AssetItem(asset: asset))
        self._assetItems = State(initialValue: assets.map { AssetItem(asset: $0) })
        self._isAsset = State(initialValue: true)
        
        // Find the index of the current item
        if let index = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
            self._selectedIndex = State(initialValue: index)
        }
    }
    
    // Helper computed properties to get the current media item
    private var currentItem: (any MediaItem)? {
        if isAsset {
            return selectedIndex < assetItems.count ? assetItems[selectedIndex] : nil
        } else {
            return selectedIndex < metadataItems.count ? metadataItems[selectedIndex] : nil
        }
    }
    
    private var currentItems: [any MediaItem] {
        isAsset ? assetItems : metadataItems
    }
    
    private var itemCount: Int {
        currentItems.count
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<itemCount, id: \.self) { index in
                    MediaItemView(
                        item: currentItems[index],
                        cache: mediaCache[index],
                        onCacheUpdate: { cache in
                            mediaCache[index] = cache
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: selectedIndex)
            .sheet(isPresented: $showMetadata) {
                if let item = currentItem {
                    if let metadataItem = item as? MetadataItem {
                        MetadataView(
                            photo: metadataItem.metadata,
                            show: $showMetadata
                        )
                    } else if let assetItem = item as? AssetItem {
                        let assetMetadata = Metadata.from(asset: assetItem.asset)
                        MetadataView(
                            photo: assetMetadata,
                            show: $showMetadata
                        )
                    }
                }
            }
        }
        .navigationTitle(currentItem?.filename ?? "Unknown File")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showMetadata = true
                }) {
                    Label("metadata", systemImage: "ellipsis.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// Cache structure to store loaded media
struct MediaCache {
    var thumbnail: UIImage?
    var fullImage: UIImage?
    var player: AVPlayer?
    var isLoadingFullData: Bool = false
}

// View for individual media items
struct MediaItemView: View {
    let item: any MediaItem
    
    // State for this specific media item
    @State private var thumbnail: UIImage?
    @State private var fullImage: UIImage?
    @State private var player: AVPlayer?
    @State private var isLoadingFullData: Bool = false
    
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    @State private var offset = CGSize.zero
    
    // Cache management
    var cache: MediaCache?
    var onCacheUpdate: (MediaCache) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let fullImage = fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(currentZoom + totalZoom)
                        .offset(offset)
                        .allowsHitTesting(totalZoom > 1.0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow dragging when zoomed in
                                    if totalZoom > 1.0 || currentZoom > 0 {
                                        offset = CGSize(
                                            width: value.translation.width + offset.width,
                                            height: value.translation.height + offset.height
                                        )
                                    }
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentZoom = value - 1
                                }
                                .onEnded { value in
                                    totalZoom += currentZoom
                                    currentZoom = 0
                                    
                                    // Reset offset if zooming out to normal
                                    if totalZoom <= 1.0 {
                                        totalZoom = 1.0
                                        offset = .zero
                                    }
                                }
                        )
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation {
                                        if totalZoom > 1.0 {
                                            // Reset zoom
                                            totalZoom = 1.0
                                            offset = .zero
                                        } else {
                                            // Zoom in
                                            totalZoom = 2.0
                                        }
                                    }
                                }
                        )
                } else if let _player = player {
                    VideoPlayer(player: _player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onAppear {
                            _player.play()
                        }
                        .onDisappear {
                            _player.pause()
                        }
                } else if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(isLoadingFullData ? ProgressView().scaleEffect(2) : nil)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(ProgressView())
                }
            }
        }
        .onAppear {
            // Load from cache if available
            if let cache = cache {
                self.thumbnail = cache.thumbnail
                self.fullImage = cache.fullImage
                self.player = cache.player
                self.isLoadingFullData = cache.isLoadingFullData
                
                // If we have a cache but no full image loaded yet, continue loading
                if cache.fullImage == nil && cache.player == nil && !cache.isLoadingFullData {
                    loadThumbnail()
                    fetchFullImage()
                }
            } else {
                // No cache, load from scratch
                loadThumbnail()
                fetchFullImage()
            }
        }
        .onChange(of: fullImage) { _, newValue in
            updateCache()
        }
        .onChange(of: thumbnail) { _, newValue in
            updateCache()
        }
        .onChange(of: player) { _, newValue in
            updateCache()
        }
        .onChange(of: isLoadingFullData) { _, newValue in
            updateCache()
        }
    }
    
    private func updateCache() {
        let newCache = MediaCache(
            thumbnail: thumbnail,
            fullImage: fullImage,
            player: player,
            isLoadingFullData: isLoadingFullData
        )
        onCacheUpdate(newCache)
    }
    
    private func loadThumbnail() {
        item.getThumbnail { image in
            self.thumbnail = image
        }
    }
    
    private func fetchFullImage() {
        guard !isLoadingFullData else { return }
        isLoadingFullData = true
        
        if item.mimeType.starts(with: "video/") {
            item.getVideoURL { url in
                if let url = url {
                    self.player = AVPlayer(url: url)
                }
                self.isLoadingFullData = false
            }
        } else if item.mimeType.starts(with: "image/") {
            item.getFullImage { image in
                self.fullImage = image
                self.isLoadingFullData = false
            }
        } else {
            print("Unsupported file type")
            isLoadingFullData = false
        }
    }
}
