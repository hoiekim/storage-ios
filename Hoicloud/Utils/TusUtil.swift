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
    let progress = Progress.uploads
    
    var apiHost: String
    var apiKey: String

    init(
        apiHost: String,
        apiKey: String
    ) {
        self.apiHost = apiHost
        self.apiKey = apiKey
        
        tusClient = try! TUSClient(
            server: URL(string: "\(apiHost)/tus")!,
            sessionIdentifier: "hoicloud_main_session",
            sessionConfiguration: .background(withIdentifier: "kim.hoie.Hoicloud.tus"),
            storageDirectory: URL(string: "/tus")!,
            chunkSize: 0
        )
        
        print("TUSClient initialized")
        print("Found \(tusClient.remainingUploads) uploads.")
        
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
    
    func uploadWithUrl(
        url: URL,
        itemId: String,
        created: Date? = nil,
        labels: [String]? = nil
    ) async {
        do {
            let filename = url.lastPathComponent
            var uploadMetadata = [
                "itemId": itemId,
                "filename": filename
            ]
            if created != nil {
                uploadMetadata["created"] = created!.ISO8601Format()
            }
            if labels != nil && !labels!.isEmpty {
                uploadMetadata["labels"] = labels!.joined(separator: ",")
            }
            let customHeaders = [
                "Authorization": "Bearer \(apiKey)",
                "Upload-Metadata": stringifyMetadata(uploadMetadata)
            ]
            try tusClient.uploadFileAt(
                filePath: url,
                customHeaders: customHeaders,
                context: uploadMetadata
            )
            progress.start(id: itemId)
        } catch {
            print("Failed to upload: \(url), \(itemId)")
            print(error)
        }
    }
    
    func retryFailedUploads() {
        do {
            let uploads = try tusClient.getStoredUploads()
            let ids = try tusClient.failedUploadIDs()
            print("Found \(ids.count) failed uploads to retry")
            for id in ids {
                let failedUpload = uploads.first { $0.id == id }
                if isUploadValid(failedUpload) {
                    do {
                        print("Retrying upload \(id)")
                        try tusClient.retry(id: id)
                    } catch {
                        print("Failed retrying upload \(id): \(error)")
                    }
                } else {
                    do {
                        print("Canceling invalid upload \(id)")
                        try tusClient.cancel(id: id)
                        try tusClient.removeCacheFor(id: id)
                    } catch {
                        print("Failed canceling upload \(id): \(error)")
                    }
                }
            }
        } catch {
            print("Could not fetch failed id's from disk")
        }
    }
    
    private func isUploadValid(_ upload: UploadInfo?) -> Bool {
        guard let upload = upload else { return false }
        let url = upload.uploadURL
        guard let scheme = url.scheme else { return false }
        guard let host = url.host() else { return false }
        if "\(scheme)://\(host)" != apiHost { return false }
        guard let headers = upload.customHeaders else { return false }
        guard let authorization = headers["Authorization"] else { return false }
        print(authorization, apiKey)
        if authorization != "Bearer \(apiKey)" { return false }
        return true
    }
    
    func remainingUploads() -> Int {
        return tusClient.remainingUploads
    }
    
    @discardableResult
    func resume() -> [(UUID, [String: String]?)] {
        return tusClient.start()
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
        guard let uploadId = context?["itemId"] else { return }
        let rate = CGFloat(bytesUploaded / totalBytes)
        progress.update(id: uploadId, rate: rate)
    }
    
    func didStartUpload(
        id: UUID,
        context: [String : String]?,
        client: TUSKit.TUSClient
    ) {
        print("TUSClient started upload, id is \(id)")
        guard let uploadId = context?["itemId"] else { return }
        progress.start(id: uploadId)
    }
    
    func didFinishUpload(
        id: UUID,
        url: URL,
        context: [String : String]?,
        client: TUSKit.TUSClient
    ) {
        print("TUSClient finished upload, id is \(id) url is \(url)")
        guard let uploadId = context?["itemId"] else { return }
        progress.complete(id: uploadId)
    }
    
    func uploadFailed(
        id: UUID,
        error: any Error,
        context: [String : String]?,
        client: TUSKit.TUSClient
    ) {
        print("TUSClient upload failed for \(id) error \(error)")
        guard let uploadId = context?["itemId"] else { return }
        progress.remove(id: uploadId)
    }
    
    func fileError(error: TUSClientError, client: TUSClient) {
        print("TUSClient File error \(error)")
    }
    
    
    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
//        print("TUSClient total progress \(bytesUploaded)/\(totalBytes)")
    }
}
