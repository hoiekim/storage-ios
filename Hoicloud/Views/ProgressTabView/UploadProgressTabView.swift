//
//  UploadProgressTabView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/11/25.
//

import SwiftUI

struct UploadProgressTabView: View {
    @Binding var showConfiguration: Bool
    @Binding var showAddItemSheet: Bool
    
    @ObservedObject private var storageApi = StorageApi.shared
    @ObservedObject var progress = Progress.uploads
    
    @AppStorage("isSyncEnabled") var isSyncEnabled = false
    
    private var progressKeys: [String] {
        return Array(progress.keys().sorted {
            let left = progress.getStartTime($0) ?? Date.distantPast
            let right = progress.getStartTime($1) ?? Date.distantPast
            return left > right
        }.prefix(20))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ProgressBarGraphView(progress: progress)
                }
                
                Section {
                    Toggle("Enable sync", isOn: $isSyncEnabled)
                    Button(action: syncNow) {
                        Text("Refresh & Sync now")
                    }
                }
                
                Section {
                    let keys = progress.keys()
                    if keys.isEmpty {
                        Text("Empty")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(progressKeys, id: \.self) { key in
                            ProgressItemView(key: key, progress: progress)
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
            .navigationTitle("Uploads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // config button
                    Button(action: startConfiguration) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .onChange(of: isSyncEnabled) { _, newValue in
            if newValue {
                resumeSync()
            }
        }
        .onAppear {
            storageApi.tusUtil.resume()
        }
    }
    
    @ViewBuilder
    private func renderShowMoreDestination() -> some View {
        MoreProgressItemsView(progress: progress, title: "All Uploads")
    }
    
    private func startConfiguration() {
        showConfiguration = true
    }
    
    private func resumeSync() {
        Task {
            await SyncUtil.shared.start()
        }
    }
    
    private func syncNow() {
        Task {
            await SyncUtil.shared.startAgain()
        }
    }
}


