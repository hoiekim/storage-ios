//
//  StorageApi.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import PhotosUI

struct Metadata: Identifiable, Codable, Equatable {
    let id: Int
    let filekey: String
    let filename: String
    let filesize: Int
    let mime_type: String
    let width: Int?
    let height: Int?
    let duration: Float?
    let altitude: Float?
    let latitude: Float?
    let longitude: Float?
    let created: String?
    let uploaded: String
    
    static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.filekey == rhs.filekey
    }
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
    
    let query = "?api_key=" + apiKey
    let routeUrlString = apiHost + "/" + route
    let encodedParam = parameter?.addingPercentEncoding(
        withAllowedCharacters: .urlHostAllowed
    )
    let fullUrlString = if encodedParam != nil {
        routeUrlString + "/" + encodedParam! + query
    } else {
        routeUrlString + query
    }
    
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
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    
    @Published var photos: [Metadata] = []
    @Published var thumbnails: [String: UIImage] = [:]
    private var fetchMetadataTask: Task<Void, Never>?
    private var fetchThumbnailTasks: [String: Task<Void, Never>] = [:]
    
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
            print("Error decoding metadata")
            print(error)
        }
        
        return false
    }
    
    func fetchMetadata() {
        self.photos = []
        
        guard let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: "metadata"
        ) else { return }
        
        fetchMetadataTask?.cancel()
        fetchMetadataTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                guard !Task.isCancelled else { return }
                
                let (data, _) = try await URLSession.shared.data(for: request)

                let decoded = try JSONDecoder().decode(MetadataResponse.self, from: data)
                guard let body = decoded.body else {
                    print("No data returned: \(decoded.message ?? "Unknown")")
                    return
                }
                
                guard !Task.isCancelled else { return }
                
                DispatchQueue.main.async {
                    for file in body {
                        let isAae = file.filename.lowercased().reversed().starts(
                            with: ".aae".reversed()
                        )
                        if !isAae {
                            self.photos.append(file)
                        }
                    }
                    self.photos.sort {
                        let s1 = $0.created ?? $0.uploaded
                        let s2 = $1.created ?? $1.uploaded
                        return s2 < s1
                    }
                }
            } catch {
                print("Error fetching metadata: \(error)")
            }
        }
    }

    func fetchThumbnail(id: String) {
        guard thumbnails[id] == nil else { return }
        
        // Cancel any existing task for this identifier
        fetchThumbnailTasks[id]?.cancel()
        fetchThumbnailTasks[id] = Task {
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
                    self.thumbnails[id] = image
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
        fetchThumbnailTasks[id]?.cancel()
        fetchThumbnailTasks[id] = nil
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
    
    func uploadFile(item: PhotosPickerItem) async {
        let itemId = item.itemIdentifier
        guard var request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: "file",
            parameter: itemId,
            method: "POST"
        ) else { return }
        
        print("Sending request to upload photo: \(item.itemIdentifier ?? "Unknown")")
        
        let boundary = UUID().uuidString
        guard let body = await prepareFileToUpload(item: item, boundary: boundary) else {
            print("No body to include in upload request")
            return
        }
        
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.fetchMetadata()
                cleanTemporaryData()
            }
        
            if let response = response as? HTTPURLResponse {
                let json = try JSONDecoder().decode(UploadResponse.self, from: data)
                let statusCode = response.statusCode
                let message = json.message ?? "Unknown"
                if 200 <= statusCode && statusCode < 300 {
                    print("Upload successful(\(statusCode)): \(message)")
                } else {
                    print("Upload failed(\(statusCode)): \(message)")
                }
            }
        } catch {
            print("Error decoding metadata")
            print(error)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.fetchMetadata()
            }
            
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

#Preview {
    ContentView()
}

