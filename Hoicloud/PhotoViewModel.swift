//
//  PhotoViewModel.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI

class PhotoViewModel: ObservableObject {
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
    
    func fetchMetadata(apiHost: String, apiKey: String) {
        guard let request = getUrlRequest(
            apiHost: apiHost,
            apiKey: apiKey,
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
//                        let s1 = $0.created ?? $0.uploaded
//                        let s2 = $1.created ?? $1.uploaded
                        let s1 = $0.uploaded
                        let s2 = $1.uploaded
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

    func fetchThumbnail(apiHost: String, apiKey: String, id: String) {
        guard thumbnails[id] == nil else { return }
        
        // Cancel any existing task for this identifier
        fetchTasks[id]?.cancel()
        fetchTasks[id] = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                guard !Task.isCancelled else { return }
                
                guard let request = getUrlRequest(
                    apiHost: apiHost,
                    apiKey: apiKey,
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
}

#Preview {
    ContentView()
}

