//
//  MoreProgressItemsView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/12/25.
//

import SwiftUI

struct MoreProgressItemsView: View {
    @ObservedObject private var storageApi = StorageApi.shared
    @ObservedObject var progress: Progress
    
    var title: String
    
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
                    Button(action: progress.clear) {
                        Text("Clear history")
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
                    }
                }
            }
            .navigationTitle(title)
        }
    }
}


