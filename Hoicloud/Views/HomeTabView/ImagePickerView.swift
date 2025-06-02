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
    @EnvironmentObject var tabRouter: TabRouter
    
    @ObservedObject private var storageApi = StorageApi.shared
    @ObservedObject private var progress = Progress.uploads
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
                await storageApi.uploadItem(item: item)
            }
        }
        show = false
        tabRouter.selectedTab = .uploads
    }
}

#Preview {
    ContentView()
}
