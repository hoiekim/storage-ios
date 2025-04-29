//
//  UploadProgressView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/28/25.
//

import SwiftUI
import PhotosUI

struct UploadProgressView: View {
    @StateObject private var storageApi = StorageApi.shared
    @StateObject private var progress = Progress.shared
    
    var body: some View {
        ZStack {
            VStack {
                if !progress.isEmpty() {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress.rate())
                        }
                        .cornerRadius(2)
                    }
                    .frame(height: 4)
                    .padding(.horizontal)
                    .animation(.linear, value: progress.rate())
                    Spacer()
                }
            }
        }
        .refreshable {
            print("refreshing")
            storageApi.downloadMetadata()
        }
    }
}
