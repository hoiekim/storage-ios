//
//  ContentView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI

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
                        viewModel.fetchMetadata(apiHost: apiHost, apiKey: apiKey)
                    }
                }
                .onChange(of: showConfiguration) {
                    viewModel.fetchMetadata(apiHost: apiHost, apiKey: apiKey)
                }
                .onChange(of: isFullScreenPresented) {
                    viewModel.fetchMetadata(apiHost: apiHost, apiKey: apiKey)
                }
                .onChange(of: showAddPhotoSheet) {
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
                .sheet(isPresented: $showAddPhotoSheet) {
                    ImagePickerView(
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
                            apiHost: apiHost,
                            apiKey: apiKey,
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
