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
    
    @State private var thumbnail: UIImage? = nil
    @State private var fullImage: UIImage? = nil
    @State private var player: AVPlayer? = nil
    @State private var isLoadingFullData = false
    @State var showMetadata = false
    
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    
    init(photo: Metadata, photos: [Metadata] = []) {
        self._metadataItem = State(initialValue: MetadataItem(metadata: photo))
        self._metadataItems = State(initialValue: photos.map { MetadataItem(metadata: $0) })
        self._isAsset = State(initialValue: false)
    }
    
    init(asset: PHAsset, assets: [PHAsset] = []) {
        self._assetItem = State(initialValue: AssetItem(asset: asset))
        self._assetItems = State(initialValue: assets.map { AssetItem(asset: $0) })
        self._isAsset = State(initialValue: true)
    }
    
    // Helper computed properties to get the current media item
    private var currentItem: (any MediaItem)? {
        isAsset ? assetItem : metadataItem
    }
    
    private var currentItems: [any MediaItem] {
        isAsset ? assetItems : metadataItems
    }

    var body: some View {
        ZStack{
            Group {
                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaledToFit()
                        .scaleEffect(currentZoom + totalZoom)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentZoom = value - 1
                                }
                                .onEnded { value in
                                    totalZoom += currentZoom
                                    currentZoom = 0
                                }
                        )
                } else if let _player = player {
                    VideoPlayer(player: _player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(currentZoom + totalZoom)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentZoom = value - 1
                                }
                                .onEnded { value in
                                    totalZoom += currentZoom
                                    currentZoom = 0
                                }
                        )
                        .onAppear {
                            _player.play()
                        }
                        .onDisappear {
                            _player.pause()
                        }
                        .onChange(of: player) {
                            player?.play()
                        }
                } else if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(isLoadingFullData ? ProgressView().scaleEffect(2) : nil)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(ProgressView())
                }
            }
            
            VStack {
                Spacer()
                
                HStack {
                    // previous item
                    Button(action: {
                        navigateToPrevious()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // next item
                    Button(action: {
                        navigateToNext()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
            .gesture(DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        navigateToNext()
                    } else if value.translation.width > 0 {
                        navigateToPrevious()
                    }
                }
            )
            .onAppear {
                loadThumbnail()
                fetchFullImage()
            }
            .onChange(of: metadataItem) { _, _ in
                resetView()
                loadThumbnail()
                fetchFullImage()
            }
            .onChange(of: assetItem) { _, _ in
                resetView()
                loadThumbnail()
                fetchFullImage()
            }
            .sheet(isPresented: $showMetadata) {
                if let metadataItem = metadataItem {
                    MetadataView(
                        photo: metadataItem.metadata,
                        show: $showMetadata
                    )
                } else if let assetItem = assetItem {
                    let assetMetadata = Metadata.from(asset: assetItem.asset)
                    MetadataView(
                        photo: assetMetadata,
                        show: $showMetadata
                    )
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
                    Label("metadata", systemImage: "ellipsis.circle")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
    
    private func navigateToPrevious() {
        player?.pause()
        
        if isAsset {
            if let currentAsset = assetItem, !assetItems.isEmpty {
                if let previousItem = previousElement(before: currentAsset, in: assetItems) {
                    assetItem = previousItem
                }
            }
        } else {
            if let currentMetadata = metadataItem, !metadataItems.isEmpty {
                if let previousItem = previousElement(before: currentMetadata, in: metadataItems) {
                    metadataItem = previousItem
                }
            }
        }
    }
    
    private func navigateToNext() {
        player?.pause()
        
        if isAsset {
            if let currentAsset = assetItem, !assetItems.isEmpty {
                if let nextItem = nextElement(after: currentAsset, in: assetItems) {
                    assetItem = nextItem
                }
            }
        } else {
            if let currentMetadata = metadataItem, !metadataItems.isEmpty {
                if let nextItem = nextElement(after: currentMetadata, in: metadataItems) {
                    metadataItem = nextItem
                }
            }
        }
    }
    
    private func resetView() {
        fullImage = nil
        player = nil
        thumbnail = nil
        isLoadingFullData = false
    }
    
    private func loadThumbnail() {
        guard let item = currentItem else { return }
        item.getThumbnail { image in
            self.thumbnail = image
        }
    }
    
    private func fetchFullImage() {
        guard !isLoadingFullData, let item = currentItem else { return }
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
