//
//  ImageStackView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 12/1/24.
//

import SwiftUI

struct ImageStackView<Content: View>: View {
    @ObservedObject private var storageApi = StorageApi.shared
    
    let photo: Metadata
    @Binding var selectedItems: [Metadata]
    @Binding var isSelecting: Bool
    @State var isSelected: Bool = false
    let destination: (() -> Content)?
    
    var body: some View {
        if isSelecting {
            stackView().onTapGesture {
                if isSelecting {
                    if isSelected {
                        selectedItems.removeAll(where: { $0 == photo })
                        isSelected = false
                    } else {
                        selectedItems.append(photo)
                        isSelected = true
                    }
                }
            }
            .onChange(of: isSelecting) {
                isSelected = false
            }
        } else {
            if let destination = destination {
                NavigationLink {
                    destination()
                } label: {
                    stackView()
                }
            } else {
                stackView()
            }
        }
    }
    
    @ViewBuilder
    private func stackView() -> some View {
        VStack {
            let screenWidth = UIScreen.main.bounds.width
            let tileHeight = screenWidth / 3
            if let filekey = photo.filekey, let thumbnail = storageApi.thumbnails[filekey] {
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
            }
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
