//
//  PhotoViewModel.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import PhotosUI

struct PhotoMetadata: Identifiable, Codable, Equatable {
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
    
    static func == (lhs: PhotoMetadata, rhs: PhotoMetadata) -> Bool {
        return lhs.filekey == rhs.filekey
    }
}

class PhotoViewModel: ObservableObject {
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    
    @Published var photos: [PhotoMetadata] = []
    @Published var selectedPhoto: PhotoMetadata? = nil
    @Published var thumbnails: [String: UIImage] = [:]
    private var fetchTasks: [String: Task<Void, Never>] = [:]
    
    func getSelectedPhotoThumbnail() -> UIImage? {
        guard let filekey = selectedPhoto?.filekey else { return nil }
        let thumbnail = thumbnails[filekey]
        return thumbnail
    }
    
    let isoFormatter = ISO8601DateFormatter()
    
    func fetchMetadata() {
        guard let request = getUrlRequest(
            apiHost: self.apiHost,
            apiKey: self.apiKey,
            route: "metadata"
        ) else { return }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching metadata")
                print(error ?? "Unknown error")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MetadataResponse.self, from: data)
                DispatchQueue.main.async {
                    var sortingPhotos: [PhotoMetadata] = []
                    for file in response.body {
                        let isAae = file.filename.reversed().starts(
                            with: ".aae".reversed()
                        )
                        if !isAae {
                            sortingPhotos.append(file)
                        }
                    }
                    sortingPhotos.sort {
                        let s1 = $0.created ?? $0.uploaded
                        let s2 = $1.created ?? $1.uploaded
                        return s2 < s1
                    }
                    self.photos = sortingPhotos
                }
            } catch {
                print("Error decoding metadata")
                print(error)
            }
        }.resume()
    }

    func fetchThumbnail(id: String) {
        guard thumbnails[id] == nil else { return }
        
        // Cancel any existing task for this identifier
        fetchTasks[id]?.cancel()
        fetchTasks[id] = Task {
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
        fetchTasks[id]?.cancel()
        fetchTasks[id] = nil
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
        
        task.resume()
    }
    
    func deleteFile(photo: PhotoMetadata) async {
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

