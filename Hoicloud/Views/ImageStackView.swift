//
//  ImageStackView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 12/1/24.
//

import SwiftUI

struct ImageStackView: View {
    @ObservedObject var storageApi: StorageApi
    var photo: Metadata
    @Binding var showFullScreen: Bool
    @Binding var selectedItem: Metadata?
    @Binding var selectedItems: [Metadata]
    @Binding var isSelecting: Bool
    
    @State var isSelected: Bool = false
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let tileHeight = screenWidth / 3
        
        VStack {
            let filekey = photo.filekey
            if let thumbnail = storageApi.thumbnails[filekey] {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(height: tileHeight)
                    .padding(0)
                    .overlay(
                        durationOverlay(photo.duration),
                        alignment: .bottomTrailing
                    )
                    .overlay(
                        alignment: .topLeading
                    ) {
                        if isSelecting {
                            let systemImage = if isSelected {
                                "checkmark.circle.fill"
                            } else {
                                "circle"
                            }
                            let color = if isSelected {
                                Color.blue
                            } else {
                                Color.white
                            }
                            ZStack {
                                if isSelected {
                                    Label("filler", systemImage: "circle.fill")
                                        .font(.system(size: 24, weight: .regular))
                                        .foregroundColor(.white)
                                        .labelStyle(.iconOnly)
                                        .padding([.leading, .top], 4)
                                }
                                Label("select", systemImage: systemImage)
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundColor(color)
                                    .labelStyle(.iconOnly)
                                    .padding([.leading, .top], 4)
                            }
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: tileHeight)
                    .overlay(ProgressView())
                    .onAppear {
                        storageApi.downloadThumbnail(
                            id: filekey
                        )
                    }
                    .onDisappear {
                        storageApi.cancelThumbnailFetch(for: filekey)
                    }
            }
        }.onTapGesture {
            if isSelecting {
                if isSelected {
                    selectedItems.removeAll(where: { $0 == photo })
                    isSelected = false
                } else {
                    selectedItems.append(photo)
                    isSelected = true
                }
            } else {
                selectedItem = photo
                showFullScreen = true
            }
        }
        .onChange(of: isSelecting) {
            isSelected = false
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
                .fontWeight(.black)
                .foregroundColor(.white)
                .padding([.trailing, .bottom], 2)
        }
    }
}

#Preview {
    ContentView()
}
