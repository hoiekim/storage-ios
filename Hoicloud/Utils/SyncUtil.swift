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

final class SyncUtil: NSObject, PHPhotoLibraryChangeObserver {
    
    static let shared = SyncUtil()
    
    private var storageApi = StorageApi.shared
    
    private let userDefaultsKey = "lastSyncedPhotoDate"
    private var lastSyncedDate: Date? {
        get {
            UserDefaults.standard.object(forKey: userDefaultsKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
        }
    }
    
    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func start() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                print("Photo access not granted")
                return
            }
            self.syncNewAssets()
        }
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.global(qos: .background).async {
            self.syncNewAssets()
        }
    }
    
    
    func syncNewAssets() {
        DispatchQueue.global(qos: .background).async {
            Task {
                var newAssets: [PHAsset] = self.fetchNewAssets(since: self.lastSyncedDate)
                
                while !newAssets.isEmpty {
                    for asset in newAssets {
                        guard let url = await self.getAssetUrl(for: asset) else { continue }
                        
                        await self.storageApi.uploadWithUrl(
                            url: url,
                            itemId: asset.localIdentifier
                        )
                        
                        if let assetDate = asset.creationDate {
                            if self.lastSyncedDate == nil || assetDate > self.lastSyncedDate! {
                                self.lastSyncedDate = assetDate
                            }
                        }
                    }
                    
                    await self.storageApi.waitForUpload(lowerThan: SYNC_BATCH_SIZE)
                    newAssets = self.fetchNewAssets(since: self.lastSyncedDate)
                }
            }
        }
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

    private func getAssetUrl(for asset: PHAsset) async -> URL? {
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
}
