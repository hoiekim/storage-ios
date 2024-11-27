//
//  ConfigurationView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/26/24.
//

import SwiftUI

struct ConfigurationView: View {
    @AppStorage("apiHost") var apiHost = ""
    @AppStorage("apiKey") var apiKey = ""
    @Binding var show: Bool
    
    @State var apiHostInput: String = ""
    @State var apiKeyInput: String = ""

    var body: some View {
        Section {
            Text("Configuration")
                .font(.system(size: 24, weight: .bold))
                .frame(alignment: Alignment.leading)
                .padding(.top, 30.0)
                .padding(.bottom, 10.0)
            Text("To setup your own storage server:")
            Link("Go to Github repository", destination: URL(string: "https://github.com/hoiekim/storage")!)
        }
        List {
            Section {
                TextField("Server Address", text: $apiHostInput)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                TextField("API Key", text: $apiKeyInput)
                    .textContentType(.password)
                    .autocapitalization(.none)
            }
            Section {
                Button(action: onSave) {
                    Text("Save")
                }
                Button(action: onCancel) {
                    Text("Cancel")
                }
            }
        }
        .onAppear {
            apiHostInput = apiHost
            apiKeyInput = apiKey
        }
        .padding()
    }
    
    private func onSave() {
        apiHost = apiHostInput
        apiKey = apiKeyInput
        show = false
    }
    
    private func onCancel() {
        show = false
    }
}

#Preview {
    ContentView()
}
