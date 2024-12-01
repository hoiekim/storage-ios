//
//  ContentView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var isFullScreenPresented = false
    @State private var showConfiguration = false
    @State private var showAddPhotoSheet = false
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    @StateObject private var viewModel = PhotoViewModel()
    @StateObject private var uploadProgress = ProgressDictionary()
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var anyOfMultiple: [String] {[
        apiHost,
        apiKey,
    ]}
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1) {
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
                            viewModel.fetchMetadata()
                        }
                    }
                    .onChange(of: anyOfMultiple) {
                        print("Refreshing")
                        viewModel.fetchMetadata()
                    }
                    .fullScreenCover(isPresented: $isFullScreenPresented) {
                        if viewModel.selectedPhoto != nil {
                            FullScreenPhotoView(
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
                    .sheet(isPresented: $showAddPhotoSheet) {
                        ImagePickerView(
                            photoViewModel: viewModel,
                            uploadProgress: uploadProgress,
                            show: $showAddPhotoSheet
                        )
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
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            
            VStack {
                if !uploadProgress.isEmpty() {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * uploadProgress.rate())
                        }
                        .cornerRadius(2)
                    }
                    .frame(height: 4)
                    .padding(.horizontal)
                    .animation(.linear, value: uploadProgress.rate())
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderStack(_ photo: PhotoMetadata) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let tileHeight = screenWidth / 3
        
        VStack {
            let filekey = photo.filekey
            if let thumbnail = viewModel.thumbnails[filekey] {
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
                            id: filekey
                        )
                    }
                    .onDisappear {
                        viewModel.cancelThumbnailFetch(for: filekey)
                    }
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
