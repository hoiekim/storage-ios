//
//  SyncUtil.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/10/25.
//

import Foundation
import Photos
import UIKit

private let SYNC_BATCH_SIZE = 20

final class SyncUtil {
    
    static let shared = SyncUtil()
    
    private let progress = Progress.uploads
    private var storageApi = StorageApi.shared
    
    private let isSyncEnabledKey = "isSyncEnabled"
    private var isSyncEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: isSyncEnabledKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isSyncEnabledKey)
        }
    }
    
    private let lastSyncedDateKey = "lastSyncedPhotoDate"
    private var lastSyncedDate: Date? {
        get {
            UserDefaults.standard.object(forKey: lastSyncedDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastSyncedDateKey)
        }
    }
    
    func start(recursively: Bool = true) async {
        guard isSyncEnabled else { return }
        
        // Check photo library authorization status
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        
        guard status == .authorized || status == .limited else {
            print("Photo access not granted")
            return
        }
        
        print("sync new assets")
        await self.storageApi.waitForUpload(lowerThan: SYNC_BATCH_SIZE)
        var newAssets: [PHAsset] = self.fetchNewAssets(since: self.lastSyncedDate)
        
        while !newAssets.isEmpty {
            for asset in newAssets {
                progress.start(id: asset.localIdentifier)
            }
            for asset in newAssets {
                guard isSyncEnabled else { return }
                guard let url = await self.getAssetUrl(for: asset) else { continue }
                
                await self.storageApi.uploadWithUrl(
                    url: url,
                    itemId: asset.localIdentifier,
                    created: asset.creationDate,
                    labels: extractLabels(from: asset)
                )
                
                if let assetDate = asset.creationDate {
                    if self.lastSyncedDate == nil || assetDate > self.lastSyncedDate! {
                        self.lastSyncedDate = assetDate
                    }
                }
            }
            
            await self.storageApi.waitForUpload(lowerThan: SYNC_BATCH_SIZE)
            print("finished a batch for sync. lastSyncedDate: \(String(describing: self.lastSyncedDate))")
            
            if recursively {
                newAssets = self.fetchNewAssets(since: self.lastSyncedDate)
            } else {
                newAssets = []
            }
        }
    }
    
    func startAgain() async {
        lastSyncedDate = nil
        await start()
    }

    private func fetchNewAssets(since date: Date?) -> [PHAsset] {
        let options = PHFetchOptions()
        options.fetchLimit = SYNC_BATCH_SIZE
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if let date = date {
            options.predicate = NSPredicate(format: "creationDate > %@", date as NSDate)
        }
        
        let result = PHAsset.fetchAssets(with: options)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image || asset.mediaType == .video {
                assets.append(asset)
            }
        }
        
        return assets
    }

    func getAssetUrl(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { input, _ in
                if let url = input?.fullSizeImageURL {
                    continuation.resume(returning: url)
                } else if let asset = input?.audiovisualAsset as? AVURLAsset {
                    continuation.resume(returning: asset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    @discardableResult
    func uploadMissingLabels() async -> Int {
        let labelMissingPhotos = storageApi.photos.filter {
            let metadata_id = $0.value.id
            let labels = storageApi.labels[metadata_id]
            return labels == nil
        }
        
        for (_, photo) in labelMissingPhotos {
            guard let filekey = photo.filekey else { continue }
            let imageData = await storageApi.getFullImageData(filekey: filekey)
            guard let imageData else { continue }
            guard let image = UIImage(data: imageData) else { continue }
            let labels = await extractLabels(from: image)
            await storageApi.uploadLabels(itemId: photo.item_id, labels: labels)
        }
        
        return labelMissingPhotos.count
    }
}
