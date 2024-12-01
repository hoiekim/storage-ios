//
//  ImagePicker.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import UIKit
import PhotosUI

struct ImagePickerView: View {
    @ObservedObject var photoViewModel: PhotoViewModel
    @ObservedObject var uploadProgress: ProgressDictionary
    @Binding var show: Bool
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        Section {
            Text("Add New Photos")
                .font(.system(size: 24, weight: .bold))
                .frame(alignment: Alignment.leading)
                .padding(.top, 30.0)
                .padding(.bottom, 10.0)
        }
        List {
            Section {
                PhotosPicker(
                    "Select Media",
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
                    uploadProgress.start(id: itemId)
                }
            }
            for item in selectedItems {
                await photoViewModel.uploadFile(item: item)
                if let itemId = item.itemIdentifier {
                    uploadProgress.complete(id: itemId)
                }
            }
            for item in selectedItems {
                if let itemId = item.itemIdentifier {
                    uploadProgress.remove(id: itemId)
                }
            }
        }
        show = false
    }
}

#Preview {
    ContentView()
}
