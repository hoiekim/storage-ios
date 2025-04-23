//
//  SyncUtil.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/10/25.
//

import Foundation
import Photos
import UIKit

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
        DispatchQueue.main.async {
            self.syncNewAssets()
        }
    }

    private func syncNewAssets() {
        let newAssets = fetchNewAssets(since: lastSyncedDate)
        guard !newAssets.isEmpty else { return }

        for asset in newAssets {
            requestURL(for: asset) { url in
                guard let fileUrl = url else { return }
                Task {
                    await self.storageApi.uploadWithUrl(
                        url: fileUrl,
                        itemId: asset.localIdentifier
                    )
                }
            }
            if let assetDate = asset.creationDate {
                if lastSyncedDate == nil || assetDate > lastSyncedDate! {
                    lastSyncedDate = assetDate
                }
            }
        }
        
        self.storageApi.startUploads()
    }

    private func fetchNewAssets(since date: Date?) -> [PHAsset] {
        let options = PHFetchOptions()
        if let date = date {
            options.predicate = NSPredicate(format: "creationDate > %@", date as NSDate)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: options)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image || asset.mediaType == .video {
                assets.append(asset)
            }
        }
        return assets
    }

    private func requestURL(for asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true

        asset.requestContentEditingInput(with: options) { input, _ in
            if let url = input?.fullSizeImageURL {
                completion(url)
            } else if let asset = input?.audiovisualAsset as? AVURLAsset {
                completion(asset.url)
            } else {
                completion(nil)
            }
        }
    }
}
