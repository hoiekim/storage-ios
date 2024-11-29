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
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
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
                    Text("Item selected: \(selectedItems.count)")
                    Button("Upload Video") {
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
        for item in selectedItems {
            Task {
                await uploadFile(
                    apiHost: apiHost,
                    apiKey: apiKey,
                    item: item
                )
                show = false
            }
        }
    }
}

#Preview {
    ContentView()
}
