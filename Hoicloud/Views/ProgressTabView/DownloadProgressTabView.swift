//
//  UploadProgressView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 4/28/25.
//

import SwiftUI

struct DownloadProgressTabView: View {
    @Binding var showConfiguration: Bool
    @Binding var showAddItemSheet: Bool
    
    @ObservedObject private var storageApi = StorageApi.shared
    @ObservedObject var progress = Progress.downloads
    
    private var progressKeys: [String] {
        return Array(progress.keys().prefix(20)).sorted {
            let left = progress.getStartTime($0) ?? Date.distantPast
            let right = progress.getStartTime($1) ?? Date.distantPast
            return left > right
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ProgressBarGraphView(progress: progress)
                }
                
                Section {
                    let keys = progress.keys()
                    if keys.isEmpty {
                        Text("Empty")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(progressKeys, id: \.self) { key in
                            HStack {
                                ProgressItemView(key: key, progress: progress)
                            }
                        }
                        if progress.size() > 20 {
                            NavigationLink(destination: renderShowMoreDestination()) {
                                Text("Show more")
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: progress.clear) {
                        Text("Clear history")
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // config button
                    Button(action: startConfiguration) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderShowMoreDestination() -> some View {
        MoreProgressItemsView(progress: progress, title: "All Downloads")
    }
    
    private func startConfiguration() {
        showConfiguration = true
    }
}
