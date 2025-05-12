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
        return progress.keys().sorted {
            let left = progress.getStartTime($0) ?? Date.distantPast
            let right = progress.getStartTime($1) ?? Date.distantPast
            return left > right
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ProgressBar(progress: progress)
                }
                
                Section {
                    Toggle("Auto sync", isOn: $isSyncEnabled)
                    Button(action: syncNow) {
                        Text("Sync now")
                    }
                }
                
                Section {
                    let keys = progress.keys()
                    if keys.isEmpty {
                        Text("Empty")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(progressKeys, id: \.self) { key in
                            HStack {
                                ProgressItem(key: key, progress: progress)
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
    }
    
    private func startConfiguration() {
        showConfiguration = true
    }
    
    private func syncNow() {
        Task {
            await SyncUtil.shared.startAgain()
        }
    }
}


