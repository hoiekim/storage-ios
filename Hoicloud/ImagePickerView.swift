//
//  ImagePickerView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import UIKit
import PhotosUI

struct ImagePickerView: View {
    @ObservedObject var storageApi: StorageApi
    @ObservedObject var progress: Progress
    @Binding var show: Bool
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        Section {
            Text("Add New Item")
                .font(.system(size: 24, weight: .bold))
                .frame(alignment: Alignment.leading)
                .padding(.top, 30.0)
                .padding(.bottom, 10.0)
        }
        List {
            Section {
                PhotosPicker(
                    "Select Item",
                    selection: $selectedItems,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                )
                
                if selectedItems.count > 0 {
                    Text("Item Selected: \(selectedItems.count)")
                    Button("Upload Selected Items") {
                        onUpload()
                    }
                }
                
                Button("Close") {
                    show = false
                }
                
            }
        }
    }
    
    private func onUpload() {
        Task {
            for item in selectedItems {
                if let itemId = item.itemIdentifier {
                    progress.start(id: itemId)
                }
            }
            for item in selectedItems {
                await storageApi.uploadFile(item: item)
                if let itemId = item.itemIdentifier {
                    progress.complete(id: itemId)
                }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
            for item in selectedItems {
                if let itemId = item.itemIdentifier {
                    progress.remove(id: itemId)
                }
            }
        }
        show = false
    }
}

#Preview {
    ContentView()
}
