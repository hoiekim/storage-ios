//
//  FullImageView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/26/24.
//

import SwiftUI
import Photos

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
    
    init(photo: Metadata, photos: [Metadata]? = nil) {
        self._metadataItem = State(initialValue: MetadataItem(metadata: photo))
        let photosArray = photos ?? [photo]
        self._metadataItems = State(initialValue: photosArray.map { MetadataItem(metadata: $0) })
        self._isAsset = State(initialValue: false)
        
        // Find the index of the current item
        if let index = photosArray.firstIndex(where: { $0.item_id == photo.item_id }) {
            self._selectedIndex = State(initialValue: index)
        }
    }
    
    init(asset: PHAsset, assets: [PHAsset]? = nil) {
        self._assetItem = State(initialValue: AssetItem(asset: asset))
        let assetsArray = assets ?? [asset]
        self._assetItems = State(initialValue: assetsArray.map { AssetItem(asset: $0) })
        self._isAsset = State(initialValue: true)
        
        // Find the index of the current item
        if let index = assetsArray.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
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
                        .presentationDragIndicator(.visible)
                    } else if let assetItem = item as? AssetItem {
                        let assetMetadata = Metadata.from(asset: assetItem.asset)
                        MetadataView(
                            photo: assetMetadata,
                            show: $showMetadata
                        )
                        .presentationDragIndicator(.visible)
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
