//
//  StorageApi.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import PhotosUI

func appendApiKey(
    to urlString: String,
    with apiKey: String
) -> String {
    return urlString + "?api_key=" + apiKey
}

func constructApiUrl(
    apiHost: String,
    apiKey: String,
    route: String = "",
    parameter: String? = nil
) -> String {
    var routeUrlString = apiHost + "/" + route
    let encodedParam = parameter?.addingPercentEncoding(
        withAllowedCharacters: .urlHostAllowed
    )
    if encodedParam != nil {
        routeUrlString = routeUrlString + "/" + encodedParam!
    }
    return appendApiKey(to: routeUrlString, with: apiKey)
}

func getUrlRequest(
    apiHost: String,
    apiKey: String,
    route: String = "",
    parameter: String? = nil,
    method: String? = "GET"
) -> URLRequest? {
    if apiHost.isEmpty || apiKey.isEmpty {
        return nil
    }

    let fullUrlString = constructApiUrl(
        apiHost: apiHost,
        apiKey: apiKey,
        route: route,
        parameter: parameter
    )
    
    guard let url = URL(string: fullUrlString) else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    
    return request
}

struct MetadataResponse: Codable {
    let message: String?
    let body: [Metadata]?
}

struct UploadResponse: Codable {
    let message: String?
}

class StorageApi: ObservableObject, @unchecked Sendable {
    static let shared = StorageApi()
    
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    
    @Published var photos: [Metadata] = []
    @Published var photosByKey: [String: Metadata] = [:]
    @Published var thumbnails: [String: UIImage] = [:]
    private var downloadMetadataTask: Task<Void, Never>?
    private var downloadThumbnailTasks: [String: Task<Void, Never>] = [:]
    
    private var _tusUtil: TusUtil?
    var tusUtil: TusUtil {
        if _tusUtil == nil || _tusUtil!._apiHost != apiHost || _tusUtil!._apiKey != apiKey {
            print("initializing tusUtil")
            _tusUtil = TusUtil(apiHost: apiHost, apiKey: apiKey)
        }
        return _tusUtil!
    }
    
    let isoFormatter = ISO8601DateFormatter()
    
    func healthCheck() async -> Bool {
        guard let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey
        ) else { return false }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
        
            if let response = response as? HTTPURLResponse {
                let json = try JSONDecoder().decode(UploadResponse.self, from: data)
                let statusCode = response.statusCode
                let message = json.message ?? "Unknown"
                if statusCode == 200 {
                    return true
                } else {
                    print("Health check failed(\(statusCode)): \(message)")
                }
            }
        } catch {
            print("Error decoding response")
            print(error)
        }
        
        return false
    }
    
    func downloadMetadata() {
        var photos: [Metadata] = []
        var photosByKey: [String: Metadata] = [:]
        
        guard let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: "metadata"
        ) else { return }
        
        downloadMetadataTask?.cancel()
        downloadMetadataTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                guard !Task.isCancelled else { return }
                
                let (data, _) = try await URLSession.shared.data(for: request)

                let decoded = try? JSONDecoder().decode(MetadataResponse.self, from: data)
                
                guard let body = decoded?.body else {
                    print("No data returned: \(decoded?.message ?? "Unknown")")
                    return
                }
                
                guard !Task.isCancelled else { return }
                
                DispatchQueue.main.async {
                    for metadata in body {
                        photos.append(metadata)
                        photosByKey[metadata.filekey] = metadata
                    }
                    photos.sort {
                        let s1 = $0.created ?? $0.uploaded
                        let s2 = $1.created ?? $1.uploaded
                        return s2 < s1
                    }
                    self.photos = photos
                    self.photosByKey = photosByKey
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
        guard let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: route.value,
            parameter: parameter
        ) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try? JSONDecoder().decode(MetadataResponse.self, from: data)
            
            guard let body = decoded?.body else {
                print("No data returned: \(decoded?.message ?? "Unknown")")
                return nil
            }
            
            let metadata = body[0]
            return metadata
        } catch {
            print("Error fetching metadata: \(error)")
            return nil
        }
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

    func downloadThumbnail(id: String) {
        guard thumbnails[id] == nil else { return }
        
        // Cancel any existing task for this identifier
        downloadThumbnailTasks[id]?.cancel()
        downloadThumbnailTasks[id] = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                guard !Task.isCancelled else { return }
                
                guard let request = getUrlRequest(
                    apiHost: self.apiHost,
                    apiKey: self.apiKey,
                    route: "thumbnail",
                    parameter: id
                ) else { return }
            
                let (data, _) = try await URLSession.shared.data(for: request)
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
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Error fetching thumbnail for identifier \(id): \(error.localizedDescription)")
                let image = UIImage(systemName: "photo.fill")
                self.thumbnails[id] = image
            }
        }
    }
    
    func cancelThumbnailFetch(for id: String) {
        downloadThumbnailTasks[id]?.cancel()
        downloadThumbnailTasks[id] = nil
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
        guard let request = getFullImageRequest(filekey: filekey) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        } catch {
            print("Failed to get full data: \(error)")
            return nil
        }
    }
    
    func uploadItem(item: PhotosPickerItem) async {
        do {
            let fileUrl = try await item.loadTransferable(type: ClonedDataUrl.self)!
            let url = fileUrl.url
            let itemId = item.itemIdentifier ?? getHash(url: url)
            if itemId != nil {
                let existing = await getMetadataByItemId(itemId: itemId!)
                if existing != nil {
                    print("Item already uploaded: \(itemId!)")
                    return
                }
                await tusUtil.uploadWithUrl(url: url, itemId: itemId!)
            }
        } catch {
            print("Failed to upload item: \(item)")
            print(error)
        }
    }
    
    func uploadWithUrl(url: URL, itemId: String) async {
        let existing = await getMetadataByItemId(itemId: itemId)
        if existing != nil {
            print("Item already uploaded: \(itemId)")
            return
        }
        await tusUtil.uploadWithUrl(url: url, itemId: itemId)
    }
    
    func waitForUpload(lowerThan: Int) async {
        while tusUtil.remainingUploads() >= lowerThan {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    func deleteFile(photo: Metadata) async {
        if apiHost.isEmpty || apiKey.isEmpty { return }
        guard let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: "file",
            parameter: String(photo.id),
            method: "DELETE"
        ) else { return }
        
        print("Sending request to delete photo: \(photo.id)")
        
        let task = URLSession.shared.dataTask(
            with: request
        ) { data, response, error in
            guard let data = data, error == nil else {
                print("Error uploading file")
                print(error ?? "Unknown error")
                return
            }
            do {
                if let response = response as? HTTPURLResponse {
                    let json = try JSONDecoder().decode(UploadResponse.self, from: data)
                    let statusCode = response.statusCode
                    let message = json.message ?? "Unknown"
                    if 200 <= statusCode && statusCode < 300 {
                        print("Delete successful(\(statusCode)): \(message)")
                        DispatchQueue.main.async {
                            self.photos.remove(at: self.photos.firstIndex(of: photo)!)
                            self.photosByKey.removeValue(forKey: photo.filekey)
                            self.thumbnails.removeValue(forKey: photo.filekey)
                        }
                    } else {
                        print("Delete failed(\(statusCode)): \(message)")
                    }
                }
            } catch {
                print("Error decoding response")
                print(error)
            }
        }
        
        task.resume()
    }
}
