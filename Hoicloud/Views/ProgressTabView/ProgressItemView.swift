//
//  ProgressItemView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/12/25.
//

import SwiftUI
import Photos

struct ProgressItemView: View {
    var key: String
    
    @ObservedObject var progress: Progress
    @State var uiImage: UIImage?
    @State var asset: PHAsset?
    @State var assetMetadata: Metadata?
    @State var assets: [PHAsset] = []
    
    @State var photo: Metadata?
    @State var photos: [Metadata] = []
    
    @ObservedObject private var storageApi = StorageApi.shared
    
    var body: some View {
        if let uiImage = uiImage {
            NavigationLink(destination: renderDestination()) {
                ZStack {
                    let progressRate = progress.getRate(key)
                    if progressRate == 1 {
                        Image(systemName: "checkmark")
                    } else {
                        Circle()
                            .stroke(lineWidth: 4)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                            .frame(height: 15)
                        Circle()
                            .trim(from: 0.0, to: progressRate)
                            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.gray)
                            .rotationEffect(Angle(degrees: 270))
                            .animation(.linear, value: progressRate)
                            .frame(height: 15)
                    }
                }
                .frame(width: 25)
                
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .padding(0)
                    .mask {
                        Circle().frame(width: 30)
                    }
                
                Text(assetMetadata?.filename ?? photo?.filename ?? "Unknown")
            }
        } else {
            // SwiftUI default spinner
            ProgressView()
                .onAppear {
                    if let photo = storageApi.photos[key] {
                        resolvePhotoMetadata(photo: photo)
                    } else {
                        resolveAsset()
                    }
                }
                .onChange(of: storageApi.thumbnails[key]) {
                    self.uiImage = storageApi.thumbnails[key]
                }
        }
    }
    
    @ViewBuilder
    private func renderDestination() -> some View {
        if let asset = asset {
            FullImageView(asset: asset)
        }
        if let photo = photo {
            FullImageView(photo: photo)
        }
    }
    
    private func resolvePhotoMetadata(photo: Metadata) {
        self.photo = photo
        storageApi.downloadThumbnail(for: key)
    }
    
    private func resolveAsset() {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [key], options: nil)
        guard let asset = assets.firstObject else { return }
        self.asset = asset
        self.assetMetadata = Metadata.from(asset: asset)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: 30, height: 30)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            uiImage = image
        }
    }
}
