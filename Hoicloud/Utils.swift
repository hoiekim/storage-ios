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

struct MetadataResponse: Codable {
    let message: String?
    let body: [PhotoMetadata]
}

struct UploadResponse: Codable {
    let message: String?
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

func prepareFileToUpload(item: PhotosPickerItem, boundary: String) async -> Data? {
    do {
        print("Preparing file to upload")
        let fileData = try await item.loadTransferable(type: Data.self)!
        
        var body = Data()
        let fileUrl = try await item.loadTransferable(type: DataUrl.self)!
        
        let filename = fileUrl.url.lastPathComponent
        let tempUrl = try writeDataToTemporaryFile(data: fileData, fileName: filename)
        
        if let identifier = item.itemIdentifier,
           let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [identifier],
                options: nil
            ).firstObject,
           let creationDate = asset.creationDate {
            setCreationDate(url: tempUrl, creationDate: creationDate)
        } else {
            print("Creation date is not updated")
        }
        
        let tempData = try Data(contentsOf: tempUrl)
        
        let contentType = item.supportedContentTypes.first
        let preferredMimeType = contentType?.preferredMIMEType
        let mimeType = preferredMimeType ?? "application/octet-stream"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(tempData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    } catch {
        print("Failed to prepare data to upload: \(error)")
        return nil
    }
}

func writeDataToTemporaryFile(data: Data, fileName: String) throws -> URL {
    let tempDirectory = FileManager.default.temporaryDirectory
    let fileURL = tempDirectory.appendingPathComponent(fileName)
    try data.write(to: fileURL)
    return fileURL
}

func setCreationDate(url: URL, creationDate: Date) {
    var attributes = [FileAttributeKey: Any]()
    attributes[.creationDate] = creationDate
    attributes[.modificationDate] = creationDate
    
    do {
        try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        print("Successfully updated creation date to: \(creationDate)")
    } catch {
        print("Failed to update creation date: \(error.localizedDescription)")
    }
}

class ProgressDictionary: ObservableObject {
    @Published var dict: [String: Bool] = [:]
    
    func start(id: String) {
        dict[id] = false
    }
    
    func complete(id: String) {
        dict[id] = true
    }
    
    func remove(id: String) {
        dict.removeValue(forKey: id)
    }
    
    func isEmpty() -> Bool {
        return dict.values.count == 0
    }
    
    func size() -> Int {
        return dict.values.count
    }
    
    func rate() -> CGFloat {
        let totalTasks = size()
        guard totalTasks > 0 else { return 1 }
        let completedTasks = dict.values.map { $0 }.filter { $0 }.count
        print(completedTasks, totalTasks)
        return CGFloat(completedTasks + 1) / CGFloat(totalTasks + 1)
    }
}

#Preview {
    ContentView()
}

