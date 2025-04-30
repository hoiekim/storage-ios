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
        NavigationView {
            List {
                Section {
                    VStack {
                        HStack {
                            Text("Total progress")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.system(size: 14))
                            Text(progress.toString())
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.gray.opacity(0.3))
                                if !progress.isEmpty() {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(.indigo)
                                            .frame(width: geometry.size.width * progress.completedRate())
                                        Rectangle()
                                            .fill(.blue)
                                            .frame(width: geometry.size.width * progress.pendingRate())
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .cornerRadius(2)
                        }
                        .frame(height: 10)
                        .animation(.linear, value: progress.totalRate())
                        .padding(.bottom, 8)
                        
                        HStack(spacing: 10) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(.indigo)
                                    .frame(width: 8, height: 8)
                                Text("Completed")
                                    .font(.system(size: 10))
                            }
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                                Text("Uploading")
                                    .font(.system(size: 10))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Section {
                    let keys = progress.keys()
                    if keys.isEmpty {
                        Text("No uploads")
                    } else {
                        ForEach(progress.keys(), id: \.self) { key in
                            HStack {
                                Text(key)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Uploads")
        }
        .refreshable {
            print("refreshing")
            storageApi.downloadMetadata()
        }
    }
}
