//
//  MediaItemView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/9/25.
//

import SwiftUI
import AVKit

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
