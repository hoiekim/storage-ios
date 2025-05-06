//
//  UploadProgressView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/28/25.
//

import SwiftUI
import PhotosUI
import Photos

struct ProgressTabView: View {
    @StateObject private var storageApi = StorageApi.shared
    @StateObject var progress: Progress
    private var progressKeys: [String] {
        return progress.keys().sorted{
            let left = progress.getStartTime($0) ?? Date.distantPast
            let right = progress.getStartTime($1) ?? Date.distantPast
            return left > right
        }
    }
    
    var title: String
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ProgressBar(progress: progress)
                }
                
                Section {
                    Button(action: {
                        progress.clear()
                    }) {
                        Text("Clear history")
                    }
                }
                
                Section {
                    let keys = progress.keys()
                    if keys.isEmpty {
                        Text("Empty")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(progressKeys, id: \.self) { key in
                            HStack {
                                ProgressItem(key: key, progress: progress)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
        }
        .refreshable {
            print("refreshing")
            storageApi.downloadMetadata()
        }
    }
}

struct ProgressBar: View {
    @StateObject var progress: Progress
    
    var body: some View {
        VStack {
            HStack {
                Text("Total progress")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 14))
                Text(progress.toString())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .diagonalStripes(
                            color1: .gray.opacity(0.15),
                            color2: .black.opacity(0.15),
                            lineWidth: 5,
                            spacing: 5
                        )
                    if !progress.isEmpty() {
                        let barWidth = geometry.size.width
                        let completed = barWidth * progress.completedRate()
                        let partial = barWidth * progress.partiallyCompletedRate()
                        let pending = barWidth * (1 - progress.overallRate())
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(.indigo)
                                .frame(width: completed)
                            Rectangle()
                                .fill(.blue)
                                .frame(width: partial)
                            Rectangle()
                                .fill(.gray)
                                .frame(width: pending)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .cornerRadius(2)
            }
            .frame(height: 10)
            .animation(.linear, value: progress.overallRate())
            .padding(.bottom, 8)
            
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.indigo)
                        .frame(width: 8, height: 8)
                    Text("Completed")
                        .font(.system(size: 10))
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    Text("Processing")
                        .font(.system(size: 10))
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(.gray)
                        .frame(width: 8, height: 8)
                    Text("Queued")
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProgressItem: View {
    var key: String
    
    @StateObject var progress: Progress
    @State var uiImage: UIImage?
    @State var asset: PHAsset?
    @State var assetMetadata: AssetMetadata?
    
    @State var photo: Metadata?
    
    private let storageApi = StorageApi.shared
    
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
            ProgressView()
                .onAppear {
                    if let photo = storageApi.photosByKey[key] {
                        resolvePhotoMetadata(photo: photo)
                    } else {
                        resolveAsset()
                    }
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
        self.uiImage = storageApi.thumbnails[key]
    }
    
    private func resolveAsset() {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [key], options: nil)
        guard let asset = assets.firstObject else { return }
        self.asset = asset
        self.assetMetadata = AssetMetadata.from(asset: asset)
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
