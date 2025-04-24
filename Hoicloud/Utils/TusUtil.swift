//
//  TusUtils.swift
//  Hoicloud
//
//  Created by Hoie Kim on 3/25/25.
//

import Foundation
import TUSKit
import SwiftUI
import PhotosUI

final class TusUtil {
    let tusClient: TUSClient
    
    var _apiHost: String
    var _apiKey: String

    init(
        apiHost: String,
        apiKey: String
    ) {
        _apiHost = apiHost
        _apiKey = apiKey
        
        tusClient = try! TUSClient(
            server: URL(string: "\(apiHost)/tus")!,
            sessionIdentifier: "hoicloud_main_session",
            sessionConfiguration: .background(withIdentifier: "TUSKit.\(apiHost).\(apiKey).background"),
            storageDirectory: URL(string: "/tus")!,
            chunkSize: 0
        )
        
        tusClient.delegate = self
    }
    
    func stringifyMetadata(_ metadata: [String: String]) -> String {
        return metadata.map { key, value in
            if let data = value.data(using: .utf8) {
                let base64Value = data.base64EncodedString()
                return "\(key) \(base64Value)"
            }
            return "\(key) \(value)"
        }.joined(separator: ",")
    }
    
    func uploadWithUrl(url: URL, itemId: String) async {
        do {
            print("url: \(url), itemId: \(itemId)")
            let filename = url.lastPathComponent
            var uploadMetadata = ["filename": filename]
            uploadMetadata["itemId"] = itemId
            let customHeaders = [
                "Authorization": "Bearer \(_apiKey)",
                "Upload-Metadata": stringifyMetadata(uploadMetadata)
            ]
            try tusClient.uploadFileAt(filePath: url, customHeaders: customHeaders)
        } catch {
            print("Failed to upload: \(url), \(itemId)")
            print(error)
        }
    }
    
    func retryFailedUploads() {
        do {
            let ids = try tusClient.failedUploadIDs()
            for id in ids {
                try tusClient.retry(id: id)
            }
        } catch {
            print("Could not fetch failed id's from disk")
        }
    }
    
    func remainingUploads() -> Int {
        return tusClient.remainingUploads
    }
}

extension TusUtil: TUSClientDelegate {
    func progressFor(
        id: UUID,
        context: [String : String]?,
        bytesUploaded: Int,
        totalBytes: Int,
        client: TUSKit.TUSClient
    ) {
//        print("TUSClient progress for \(id), uploaded \(bytesUploaded)/\(totalBytes)")
    }
    
    func didStartUpload(
        id: UUID,
        context: [String : String]?,
        client: TUSKit.TUSClient
    ) {
        print("TUSClient started upload, id is \(id)")
    }
    
    func didFinishUpload(
        id: UUID,
        url: URL,
        context: [String : String]?,
        client: TUSKit.TUSClient
    ) {
        print("TUSClient finished upload, id is \(id) url is \(url)")
    }
    
    func uploadFailed(
        id: UUID,
        error: any Error,
        context: [String : String]?,
        client: TUSKit.TUSClient
    ) {
        print("TUSClient upload failed for \(id) error \(error)")
    }
    
    func fileError(error: TUSClientError, client: TUSClient) {
        print("TUSClient File error \(error)")
    }
    
    
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
//        print("TUSClient total progress \(bytesUploaded)/\(totalBytes)")
    }
}
