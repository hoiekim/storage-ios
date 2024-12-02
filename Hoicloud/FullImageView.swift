//
//  FullImageView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/26/24.
//

import SwiftUI
import AVKit

func nextElement<T: Equatable>(after element: T, in array: [T]) -> T? {
    guard let currentIndex = array.firstIndex(of: element) else {
        return nil
    }
    let nextIndex = currentIndex + 1
    return nextIndex < array.count ? array[nextIndex] : nil
}

func previousElement<T: Equatable>(before element: T, in array: [T]) -> T? {
    guard let currentIndex = array.firstIndex(of: element) else {
        return nil
    }
    let previousIndex = currentIndex - 1
    return previousIndex >= 0 ? array[previousIndex] : nil
}

struct FullImageView: View {
    @Binding var isPresented: Bool
    @ObservedObject var storageApi: StorageApi
    @Binding var selectedItem: Metadata?
    
    @State var targetItem: Metadata? = nil
    @State private var thumbnail: UIImage? = nil
    @State private var fullImage: UIImage? = nil
    @State private var player: AVPlayer? = nil
    @State private var isLoadingFullData = false
    @State var showMetadata = false
    
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0

    var body: some View {
        ZStack{
            Group {
                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaledToFit()
                        .scaleEffect(currentZoom + totalZoom)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentZoom = value - 1
                                }
                                .onEnded { value in
                                    totalZoom += currentZoom
                                    currentZoom = 0
                                }
                        )
                } else if let _player = player {
                    VideoPlayer(player: _player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(currentZoom + totalZoom)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    currentZoom = value - 1
                                }
                                .onEnded { value in
                                    totalZoom += currentZoom
                                    currentZoom = 0
                                }
                        )
                        .onAppear {
                            _player.play()
                        }
                        .onDisappear {
                            _player.pause()
                        }
                        .onChange(of: player) {
                            player?.play()
                        }
                } else if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(isLoadingFullData ? ProgressView().scaleEffect(2) : nil)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(ProgressView())
                }
            }
            
            VStack {
                HStack {
                    Button(action: {
                        totalZoom = 1
                        currentZoom = 0
                        isPresented = false
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        showMetadata = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                HStack {
                    Button(action: {
                        if let targetItem = self.targetItem {
                            player?.pause()
                            self.targetItem = previousElement(
                                before: targetItem,
                                in: self.storageApi.photos
                            )
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if let targetItem = self.targetItem {
                            player?.pause()
                            self.targetItem = nextElement(
                                after: targetItem,
                                in: self.storageApi.photos
                            )
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
            .gesture(DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        if let targetItem = self.targetItem {
                            player?.pause()
                            self.targetItem = previousElement(
                                before: targetItem,
                                in: self.storageApi.photos
                            )
                        }
                    } else if value.translation.width > 0 {
                        if let targetItem = self.targetItem {
                            player?.pause()
                            self.targetItem = nextElement(
                                after: targetItem,
                                in: self.storageApi.photos
                            )
                        }
                    }
                }
            )
            .onAppear {
                if let selectedItem = selectedItem {
                    targetItem = selectedItem
                }
                if let filekey = targetItem?.filekey {
                    thumbnail = storageApi.thumbnails[filekey]
                }
            }
            .onChange(of: targetItem) {
                fetchFullImage()
            }
            .sheet(isPresented: $showMetadata) {
                if let targetItem {
                    MetadataView(
                        photo: targetItem,
                        storageApi: storageApi,
                        show: $showMetadata,
                        isFullScreenShow: $isPresented
                    )
                }
            }
            
        }
    }
    
    private func fetchFullImage() {
        guard !isLoadingFullData else { return }
        isLoadingFullData = true
        
        guard let photo = targetItem else { return }
        let filekey = photo.filekey
        let mimetype = photo.mime_type
        
        if mimetype.starts(with: "video/") {
            let request = storageApi.getFullImageRequest(filekey: filekey)
            if let url = request?.url {
                self.player = AVPlayer(url: url)
            }
            isLoadingFullData = false
        } else if mimetype.starts(with: "image/") {
            Task {
                if let data = await storageApi.getFullImageData(filekey: filekey) {
                    if let image = UIImage(data: data) {
                        self.fullImage = image
                    } else {
                        print("Failed to decode full-size image")
                    }
                    isLoadingFullData = false
                }
            }
        } else {
            print("Unsupported file type")
            isLoadingFullData = false
        }
    }
}

#Preview {
    ContentView()
}
