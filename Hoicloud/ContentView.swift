//
//  ContentView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI

func getUrlRequest(
    apiHost: String,
    apiKey: String,
    route: String,
    parameter: String? = nil
) -> URLRequest? {
    if apiHost.isEmpty || apiKey.isEmpty {
        return nil
    }
    
    let query = "?api_key=" + apiKey
    
    let routeUrlString = apiHost + "/" + route
    let fullUrlString = if (parameter != nil) {
        routeUrlString + "/" + parameter! + query
    } else {
        routeUrlString + query
    }
    
    let url = URL(string: fullUrlString)!
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    return request
}

struct PhotoMetadata: Identifiable, Codable, Equatable {
    let id: Int
    let filekey: String
    let filename: String
    let filesize: Int
    let mime_type: String
    let width: Int?
    let height: Int?
    let duration: Float?
    let thumbnail_id: String?
    let altitude: Float?
    let latitude: Float?
    let longitude: Float?
    let created: String?
    let uploaded: String
    
    static func == (lhs: PhotoMetadata, rhs: PhotoMetadata) -> Bool {
        return lhs.filekey == rhs.filekey
    }
}

struct MetadataResponse: Codable {
    let message: String?
    let body: [PhotoMetadata]
}

class PhotoViewModel: ObservableObject {
    @Published var photos: [PhotoMetadata] = []
    @Published var selectedPhoto: PhotoMetadata? = nil
    @Published var thumbnails: [String: UIImage] = [:]
    private var fetchTasks: [String: Task<Void, Never>] = [:]
    
    func getSelectedPhotoThumbnail() -> UIImage? {
        guard let thumbnail_id = selectedPhoto?.thumbnail_id else { return nil }
        let thumbnail = thumbnails[thumbnail_id]
        return thumbnail
    }
    
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
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Error fetching thumbnail for identifier \(id): \(error.localizedDescription)")
            }
        }
    }
    
    func cancelThumbnailFetch(for id: String) {
        fetchTasks[id]?.cancel()
        fetchTasks[id] = nil
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PhotoViewModel()
    @State private var isFullScreenPresented = false
    @State private var showConfiguration = false
    @State private var showAddPhotoSheet = false
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(viewModel.photos) { photo in
                            renderStack(photo)
                        }
                    }
                }
                .navigationTitle("Hoicloud Photos")
                .onAppear {
                    if apiHost.isEmpty || apiKey.isEmpty {
                        showConfiguration = true
                    } else {
                        viewModel.fetchMetadata(apiHost: apiHost, apiKey: apiKey)
                    }
                }
                .onChange(of: apiHost) {
                    viewModel.fetchMetadata(apiHost: apiHost, apiKey: apiKey)
                }
                .onChange(of: apiKey) {
                    viewModel.fetchMetadata(apiHost: apiHost, apiKey: apiKey)
                }
                .fullScreenCover(isPresented: $isFullScreenPresented) {
                    if viewModel.selectedPhoto != nil {
                        FullScreenPhotoView(
                            apiHost: $apiHost,
                            apiKey: $apiKey,
                            isPresented: $isFullScreenPresented,
                            photoViewModel: viewModel
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showConfiguration = true
                        }) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
                .sheet(isPresented: $showConfiguration) {
                    ConfigurationView(
                        apiHost: apiHost,
                        apiKey: apiKey,
                        show: $showConfiguration)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showAddPhotoSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(
                                    color: .black,
                                    radius: 15,
                                    x: 5,
                                    y: 10
                                )
                        }
                        .padding()
                        .sheet(isPresented: $showAddPhotoSheet) {
    //                        AddPhotoView()
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private func renderStack(_ photo: PhotoMetadata) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let tileHeight = screenWidth / 3
        
        VStack {
            if let thumbnail_id = photo.thumbnail_id {
                if let thumbnail = viewModel.thumbnails[thumbnail_id] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(height: tileHeight)
                        .padding(0)
                        .overlay(
                            durationOverlay(photo.duration),
                            alignment: .bottomTrailing
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: tileHeight)
                        .overlay(ProgressView())
                        .onAppear {
                            viewModel.fetchThumbnail(
                                apiHost: apiHost,
                                apiKey: apiKey,
                                id: thumbnail_id
                            )
                        }
                        .onDisappear {
                            viewModel.cancelThumbnailFetch(for: thumbnail_id)
                        }
                }
            } else {
                Image(systemName: "photo.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: tileHeight)
                    .foregroundColor(.gray)
            }
        }.onTapGesture {
            viewModel.selectedPhoto = photo
            isFullScreenPresented = true
        }
    }
    
    @ViewBuilder
    private func durationOverlay(_ duration: Float?) -> some View {
        if let duration = duration {
            let totalSeconds = Int(duration.rounded())
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            Text(String(format: "%d:%02d", minutes, seconds))
                .font(.caption)
                .padding(4)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .padding([.trailing, .bottom], 8)
        }
    }
}

#Preview {
    ContentView()
}
