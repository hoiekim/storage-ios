//
//  Utils.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI
import PhotosUI
import Foundation
import UniformTypeIdentifiers

func getUrlRequest(
    apiHost: String,
    apiKey: String,
    route: String,
    parameter: String? = nil,
    method: String? = "GET"
) -> URLRequest? {
    if apiHost.isEmpty || apiKey.isEmpty {
        return nil
    }
    
    let query = "?api_key=" + apiKey
    let routeUrlString = apiHost + "/" + route
    let encodedParam = parameter?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    let fullUrlString = if encodedParam != nil {
        routeUrlString + "/" + encodedParam! + query
    } else {
        routeUrlString + query
    }
    
    guard let url = URL(string: fullUrlString) else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    
    return request
}

struct PhotoMetadata: Identifiable, Codable, Equatable {
    let id: Int
    let filekey: String
    let filename: String
    let filesize: Int
    let mime_type: String
    let width: Int?
    let height: Int?
    let duration: Float?
    let altitude: Float?
    let latitude: Float?
    let longitude: Float?
    let created: String?
    let uploaded: String
    
    static func == (lhs: PhotoMetadata, rhs: PhotoMetadata) -> Bool {
        return lhs.filekey == rhs.filekey
    }
}

struct MetadataResponse: Codable {
    let message: String?
    let body: [PhotoMetadata]
}

struct UploadResponse: Codable {
    let message: String?
}

func uploadFile(
    apiHost: String,
    apiKey: String,
    item: PhotosPickerItem
) async {
    if apiHost.isEmpty || apiKey.isEmpty { return }
    let itemId = item.itemIdentifier
    guard var request = getUrlRequest(
        apiHost: apiHost,
        apiKey: apiKey,
        route: "file",
        parameter: itemId,
        method: "POST"
    ) else { return }
    
    print("Sending request to upload photo: \(item)")
    
    do {
        let fileData = try await item.loadTransferable(type: Data.self)
        guard let fileData = fileData else { return }
        
        var body = Data()
        let boundary = UUID().uuidString
        let fileUrl = try await item.loadTransferable(type: DataUrl.self)
        let filename = fileUrl?.url.lastPathComponent ?? "unknown"
        let contentType = item.supportedContentTypes.first
        let preferredMimeType = contentType?.preferredMIMEType
        let mimeType = preferredMimeType ?? "application/octet-stream"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(
            with: request
        ) { data, response, error in
            guard let data = data, error == nil else {
                print("Error uploading file")
                print(error ?? "Unknown error")
                return
            }
            do {
                if let response = response as? HTTPURLResponse {
                    let json = try JSONDecoder().decode(UploadResponse.self, from: data)
                    let statusCode = response.statusCode
                    let message = json.message ?? "Unknown"
                    if 200 <= statusCode && statusCode < 300 {
                        print("Upload successful(\(statusCode)): \(message)")
                    } else {
                        print("Upload failed(\(statusCode)): \(message)")
                    }
                }
            } catch {
                print("Error decoding metadata")
                print(error)
            }
        }
        
        task.resume()
    } catch {
        print("Failed to load file: \(error)")
    }
}

func deleteFile(
    apiHost: String,
    apiKey: String,
    photo: PhotoMetadata
) async {
    if apiHost.isEmpty || apiKey.isEmpty { return }
    guard let request = getUrlRequest(
        apiHost: apiHost,
        apiKey: apiKey,
        route: "file",
        parameter: String(photo.id),
        method: "DELETE"
    ) else { return }
    
    print("Sending request to delete photo: \(photo.id)")
    
    let task = URLSession.shared.dataTask(
        with: request
    ) { data, response, error in
        guard let data = data, error == nil else {
            print("Error uploading file")
            print(error ?? "Unknown error")
            return
        }
        do {
            if let response = response as? HTTPURLResponse {
                let json = try JSONDecoder().decode(UploadResponse.self, from: data)
                let statusCode = response.statusCode
                let message = json.message ?? "Unknown"
                if 200 <= statusCode && statusCode < 300 {
                    print("Delete successful(\(statusCode)): \(message)")
                } else {
                    print("Delete failed(\(statusCode)): \(message)")
                }
            }
        } catch {
            print("Error decoding response")
            print(error)
        }
    }
    
    task.resume()
}

struct DataUrl: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { data in
            SentTransferredFile(data.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}

#Preview {
    ContentView()
}

