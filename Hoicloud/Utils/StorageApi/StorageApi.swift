//
//  StorageApi.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import PhotosUI

struct MetadataResponse: Codable {
    let message: String?
    let body: [Metadata]?
}

struct UploadResponse: Codable {
    let message: String?
}

struct LabelsResponse: Codable {
    let message: String?
    let body: [MetadataLabel]?
}

class StorageApi: ObservableObject, @unchecked Sendable {
    static let shared = StorageApi()
    private let fetch = Fetch()
    
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    
    @Published var photos: [String: Metadata] = [:]
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var labels: [Int: [String]] = [:]
    
    private var _tusUtil: TusUtil?
    var tusUtil: TusUtil {
        if _tusUtil == nil || _tusUtil!.apiHost != apiHost || _tusUtil!.apiKey != apiKey {
            print("initializing tusUtil")
            _tusUtil = TusUtil(apiHost: apiHost, apiKey: apiKey)
            _tusUtil!.retryFailedUploads()
        }
        return _tusUtil!
    }
    
    let isoFormatter = ISO8601DateFormatter()
    
    func healthCheck() async -> Bool {
        guard let fetchResult = await fetch.json(UploadResponse.self) else { return false }
        let (statusCode, json) = fetchResult
        let message = json.message ?? "Unknown"
        if statusCode == 200 {
            return true
        } else {
            print("Health check failed(\(statusCode)): \(message)")
        }
        
        return false
    }
    
    private var downloadMetadataTask: Task<Void, Never>?
    
    func downloadMetadata() {
        downloadMetadataTask?.cancel()
        downloadMetadataTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                guard !Task.isCancelled else { return }
                guard let fetchResult = await fetch.json(
                    MetadataResponse.self,
                    route: "metadata"
                ) else { return }
                let (_, json) = fetchResult
                
                guard let body = json.body else {
                    print("No data returned: \(json.message ?? "Unknown")")
                    return
                }
                
                guard !Task.isCancelled else { return }
                
                DispatchQueue.main.async {
                    var photosByKey: [String: Metadata] = [:]
                    for metadata in body {
                        if let filekey = metadata.filekey {
                            photosByKey[filekey] = metadata
                        }
                    }
                    self.photos = photosByKey
                }
            } catch {
                print("Error fetching metadata: \(error)")
            }
        }
    }
    
    enum MetadataRouteName: String {
        case metadataById, metadataByFilekey, metadataByItemId
        var value: String {
            switch self {
            case .metadataById: return "metadata-by-id"
            case .metadataByFilekey: return "metadata-by-filekey"
            case .metadataByItemId: return "metadata-by-item-id"
            }
        }
    }
    
    func getMetadata(route: MetadataRouteName, parameter: String? = nil) async -> Metadata? {
        guard let fetchResult = await fetch.json(
            MetadataResponse.self,
            route: route.value,
            parameter: parameter
        ) else { return nil }
        let (_, json) = fetchResult
        guard let body = json.body else {
            print("No data returned: \(json.message ?? "Unknown")")
            return nil
        }
        let metadata = body[0]
        return metadata
    }
    
    func getMetadataById(id: String) async -> Metadata? {
        return await getMetadata(route: .metadataById, parameter: id)
    }
    
    func getMetadataByFilekey(filekey: String) async -> Metadata? {
        return await getMetadata(route: .metadataByFilekey, parameter: filekey)
    }
    
    func getMetadataByItemId(itemId: String) async -> Metadata? {
        return await getMetadata(route: .metadataByItemId, parameter: itemId)
    }
    
    private var downloadLablesTask: Task<Void, Never>?
    
    func downloadLabels() {
        downloadLablesTask?.cancel()
        downloadLablesTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                guard !Task.isCancelled else { return }
                guard let fetchResult = await fetch.json(
                    LabelsResponse.self,
                    route: "labels"
                ) else { return }
                let (_, json) = fetchResult
                
                guard let body = json.body else {
                    print("No data returned: \(json.message ?? "Unknown")")
                    return
                }
                
                guard !Task.isCancelled else { return }
                
                DispatchQueue.main.async {
                    var labels: [Int: [String]] = [:]
                    for label in body {
                        if labels[label.metadata_id] == nil {
                            labels[label.metadata_id] = [label.labelname]
                        } else {
                            labels[label.metadata_id]!.append(label.labelname)
                        }
                    }
                    self.labels = labels
                }
            } catch {
                print("Error fetching labels: \(error)")
            }
        }
    }
    
    private var downloadThumbnailTasks: [String: Task<Void, Never>] = [:]

    func downloadThumbnail(for id: String) {
        guard thumbnails[id] == nil else { return }
        guard downloadThumbnailTasks[id] == nil else { return }
        
        downloadThumbnailTasks[id] = Task {
            guard !Task.isCancelled else { return }
            guard let fetchResult = await fetch.data(
                route: "thumbnail",
                parameter: id
            ) else { return }
            let (_, data) = fetchResult
            guard !Task.isCancelled else { return }
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.thumbnails[id] = image
                }
            } else {
                print("Error decoding thumbnail for identifier: \(id)")
                let image = UIImage(systemName: "photo.fill")
                DispatchQueue.main.async {
                    self.thumbnails[id] = image
                }
                downloadThumbnailTasks[id] = nil
            }
        }
    }
    
    func uncacheThumbnail(for id: String) {
        thumbnails[id] = nil
    }
    
    func getFullImageRequest(filekey: String) -> URLRequest? {
        if let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: "file",
            parameter: filekey
        ) {
            return request
        } else { return nil }
    }
    
    func getFullImageData(filekey: String) async -> Data? {
        guard let fetchResult = await fetch.data(
            route: "file",
            parameter: filekey
        ) else {
            print("Failed to get full data: \(filekey)")
            return nil
        }
        
        let (_, data) = fetchResult
        return data
    }
    
    func uploadItem(item: PhotosPickerItem) async {
        do {
            let fileUrl = try await item.loadTransferable(type: ClonedDataUrl.self)!
            let url = fileUrl.url
            guard let itemId = item.itemIdentifier ?? getHash(url: url) else { return }
            let existing = await getMetadataByItemId(itemId: itemId)
            if existing != nil {
                print("Item already uploaded: \(itemId)")
                Progress.uploads.complete(id: itemId)
                return
            }
            let created = await getCreationDate(from: item)
            let labels = await extractLabels(from: item)
            await tusUtil.uploadWithUrl(
                url: url,
                itemId: itemId,
                created: created,
                labels: labels
            )
        } catch {
            print("Failed to upload item: \(item)")
            print(error)
        }
    }
    
    func uploadWithUrl(
        url: URL,
        itemId: String,
        created: Date? = nil,
        labels: [String]? = nil
    ) async {
        let existing = await getMetadataByItemId(itemId: itemId)
        if existing != nil {
            print("Item already uploaded: \(itemId)")
            Progress.uploads.complete(id: itemId)
            return
        }
        await tusUtil.uploadWithUrl(
            url: url,
            itemId: itemId,
            created: created,
            labels: labels
        )
    }
    
    func waitForUpload(lowerThan: Int) async {
        while tusUtil.remainingUploads() >= lowerThan {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    func deleteFile(photo: Metadata) async {
        guard let fetchResult = await fetch.json(
            UploadResponse.self,
            method: "DELETE",
            route: "file",
            parameter: String(photo.id)
        ) else { return }
        
        let (statusCode, json) = fetchResult
        let message = json.message ?? "Unknown"
        if 200 <= statusCode && statusCode < 300 {
            print("Delete successful(\(statusCode)): \(message)")
            DispatchQueue.main.async {
                if let filekey = photo.filekey {
                    self.photos.removeValue(forKey: filekey)
                    self.thumbnails.removeValue(forKey: filekey)
                }
            }
        } else {
            print("Delete failed(\(statusCode)): \(message)")
        }
    }
    
    func uploadLabels(itemId: String, labels: [String]) async {
        guard let fetchResult = await fetch.json(
            UploadResponse.self,
            method: "POST",
            route: "labels",
            parameter: itemId,
            body: labels
        ) else { return }
        
        let (statusCode, json) = fetchResult
        let message = json.message ?? "Unknown"
        if 200 > statusCode && statusCode >= 300 {
            print("Uploading labels failed(\(statusCode)): \(message)")
        }
    }
}
