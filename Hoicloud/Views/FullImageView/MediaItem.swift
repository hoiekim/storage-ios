//
//  MediaItem.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/9/25.
//

import SwiftUI
import Photos

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
