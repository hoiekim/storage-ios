//
//  Metadata.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/6/25.
//

import Foundation
import Photos
import UIKit
import CoreLocation

struct Metadata: Identifiable, Codable, Equatable {
    let id: Int
    let item_id: String
    let filekey: String?
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
    let uploaded: String?
    
    static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return lhs.filekey == rhs.filekey
    }
    
    static func from(asset: PHAsset, id: Int = 0) -> Metadata {
        // Get itemId
        let itemId = asset.localIdentifier
        
        let resource = PHAssetResource.assetResources(for: asset).first
        
        // Get filename
        var filename = ""
        if let resource = resource {
            filename = resource.originalFilename
        }
        
        // Get mime type
        var mimeType = "application/octet-stream"
        switch asset.mediaType {
        case .image:
            if filename.lowercased().hasSuffix(".png") {
                mimeType = "image/png"
            } else if filename.lowercased().hasSuffix(".gif") {
                mimeType = "image/gif"
            } else if filename.lowercased().hasSuffix(".heic") {
                mimeType = "image/heic"
            } else if filename.lowercased().hasSuffix(".jpg") {
                mimeType = "image/jpeg"
            } else if filename.lowercased().hasSuffix(".jpeg") {
                mimeType = "image/jpeg"
            } else {
                mimeType = "image/unknown"
            }
        case .video:
            mimeType = "video/mp4"
        case .audio:
            mimeType = "audio/mp4"
        default:
            mimeType = "application/octet-stream"
        }
        
        // Get file size
        var filesize = 0
        if let resource = resource {
            if let size = resource.value(forKey: "fileSize") as? Int {
                filesize = size
            }
        }
        
        // Get dimensions
        let width = asset.pixelWidth
        let height = asset.pixelHeight
        
        // Get duration for videos
        let duration = asset.mediaType == .video ? Float(asset.duration) : nil
        
        // Get location data
        var altitude: Float? = nil
        var latitude: Float? = nil
        var longitude: Float? = nil
        
        if let location = asset.location {
            altitude = Float(location.altitude)
            latitude = Float(location.coordinate.latitude)
            longitude = Float(location.coordinate.longitude)
        }
        
        // Format creation date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        var created: String? = nil
        if let creationDate = asset.creationDate {
            created = dateFormatter.string(from: creationDate)
        }
        
        return Metadata(
            id: id,
            item_id: itemId,
            filekey: nil,
            filename: filename,
            filesize: filesize,
            mime_type: mimeType,
            width: width,
            height: height,
            duration: duration,
            altitude: altitude,
            latitude: latitude,
            longitude: longitude,
            created: created,
            uploaded: nil
        )
    }
}

struct MetadataLabel: Identifiable, Codable, Equatable  {
    let id: Int;
    let metadata_id: Int;
    let user_id: Int;
    let labelname: String;
}
