//
//  FullScreenPhotoView.swift
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

struct FullScreenPhotoView: View {
    @Binding var isPresented: Bool
    @ObservedObject var photoViewModel: PhotoViewModel
    @Binding var selectedPhoto: PhotoMetadata?
    
    @State var targetPhoto: PhotoMetadata? = nil
    @State private var thumbnail: UIImage? = nil
    @State private var fullImage: UIImage? = nil
    @State private var player: AVPlayer? = nil
    @State private var isLoadingFullData = false
    @State var showMetadata = false
    

    var body: some View {
        VStack {
            HStack {
                Button(action: {
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
            
            Group {
                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let _player = player {
                    VideoPlayer(player: _player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            Spacer()
            
            HStack {
                Button(action: {
                    if let targetPhoto = self.targetPhoto {
                        player?.pause()
                        self.targetPhoto = previousElement(
                            before: targetPhoto,
                            in: self.photoViewModel.photos
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
                    if let targetPhoto = self.targetPhoto {
                        player?.pause()
                        self.targetPhoto = nextElement(
                            after: targetPhoto,
                            in: self.photoViewModel.photos
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
                    if let targetPhoto = self.targetPhoto {
                        player?.pause()
                        self.targetPhoto = previousElement(
                            before: targetPhoto,
                            in: self.photoViewModel.photos
                        )
                    }
                } else if value.translation.width > 0 {
                    if let targetPhoto = self.targetPhoto {
                        player?.pause()
                        self.targetPhoto = nextElement(
                            after: targetPhoto,
                            in: self.photoViewModel.photos
                        )
                    }
                }
            }
        )
        .onAppear {
            if let selectedPhoto = selectedPhoto {
                targetPhoto = selectedPhoto
            }
            if let filekey = targetPhoto?.filekey {
                thumbnail = photoViewModel.thumbnails[filekey]
            }
        }
        .onChange(of: targetPhoto) {
            fetchFullImage()
        }
        .sheet(isPresented: $showMetadata) {
            if let targetPhoto {
                MetadataView(
                    photo: targetPhoto,
                    photoViewModel: photoViewModel,
                    show: $showMetadata,
                    isFullScreenShow: $isPresented
                )
            }
        }
    }
    
    private func fetchFullImage() {
        guard !isLoadingFullData else { return }
        isLoadingFullData = true
        
        guard let photo = targetPhoto else { return }
        let filekey = photo.filekey
        let filename = photo.filename
        
        guard let request = photoViewModel.getFullImageRequest(
            filekey: filekey
        ) else {
            return
        }
        
        if isVideoFile(filename) {
            if let url = request.url {
                self.player = AVPlayer(url: url)
            }
            isLoadingFullData = false
        } else if isImageFile(filename) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.fullImage = image
                        }
                    } else {
                        print("Failed to decode full-size image")
                    }
                } catch {
                    print("Error fetching full-size image: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    isLoadingFullData = false
                }
            }
        } else {
            print("Unsupported file type")
            isLoadingFullData = false
        }
    }
    
    private func isImageFile(_ filename: String) -> Bool {
        return ["jpg", "jpeg", "png"].contains(filename.lowercased().split(separator: ".").last ?? "")
    }

    private func isVideoFile(_ filename: String) -> Bool {
        return ["mov", "mp4"].contains(filename.lowercased().split(separator: ".").last ?? "")
    }
}

#Preview {
    ContentView()
}
