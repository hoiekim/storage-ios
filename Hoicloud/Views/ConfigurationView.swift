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
    @ObservedObject private var storageApi = StorageApi.shared
    
    @State var apiHostInput: String = ""
    @State var apiKeyInput: String = ""
    @State var isApiHealthy: Bool?
    @FocusState private var focusedField: String?
    
    var isInputEmpty: Bool { apiHostInput.isEmpty || apiKeyInput.isEmpty }

    var body: some View {
        VStack {
            Section {
                Text("Server Configuration")
                    .font(.system(size: 24, weight: .bold))
                    .frame(alignment: .leading)
                    .padding(.top, 30.0)
                    .padding(.bottom, 10.0)
                Text("This app requires a storage server setup.\nPlease configure your server details below.")
                    .multilineTextAlignment(.center)
                    .padding(.leading, 30.0)
                    .padding(.trailing, 30.0)
                    .padding(.top, 30.0)
                    .padding(.bottom, 10.0)
                Link("Tap to see instruction", destination: URL(
                    string: "https://github.com/hoiekim/storage"
                )!)
            }
            List {
                Section {
                    TextField("Server Address", text: $apiHostInput)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: "apiHostInput")
                    TextField("API Key", text: $apiKeyInput)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: "apiKeyInput")
                } footer: {
                    if isInputEmpty {
                        Text("Server Address and API Key are required.")
                            .font(.system(size: 14))
                    } else if isApiHealthy == true {
                        Text("Successfully connected with the server.")
                            .font(.system(size: 14))
                    } else if isApiHealthy == false {
                        Text("Failed to connect to the server. Please make sure the server is running, and the address and API key are correct.")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
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
                if isInputEmpty {
                    if apiHostInput.isEmpty {
                        focusedField = "apiHostInput"
                    } else {
                        focusedField = "apiKeyInput"
                    }
                } else {
                    Task {
                        await updateHealth()
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .interactiveDismissDisabled(isApiHealthy != true)
    }
    
    private func onSave() {
        Task {
            apiHost = apiHostInput
            apiKey = apiKeyInput
            if await updateHealth() {
                do { try? await Task.sleep(nanoseconds: 500_000_000) }
                show = false
            }
        }
    }
    
    private func onCancel() {
        Task {
            if await updateHealth() {
                show = false
            }
        }
    }
    
    private func closeIfHealthy() async {
        if await updateHealth() {
            do { try? await Task.sleep(nanoseconds: 500_000_000) }
            show = false
        }
    }
    
    private func updateHealth() async -> Bool {
        if apiHostInput.isEmpty {
            focusedField = "apiHostInput"
            isApiHealthy = nil
            return false
        } else if apiKeyInput.isEmpty {
            focusedField = "apiKeyInput"
            isApiHealthy = nil
            return false
        }
        
        if await storageApi.healthCheck() {
            isApiHealthy = true
            return true
        } else {
            isApiHealthy = false
            return false
        }
    }
}

#Preview {
    ContentView()
}
