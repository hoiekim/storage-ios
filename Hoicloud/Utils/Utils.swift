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
import BackgroundTasks
import CryptoKit

struct ClonedDataUrl: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { data in
            SentTransferredFile(data.url)
        } importing: { received in
            let fileName = received.file.lastPathComponent
            let copy: URL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.copyItem(at: received.file, to: copy)
            }
            return .init(url: copy)
        }
    }
}

func cleanTemporaryDirectory(olderThan days: Int = 2) {
    Task {
        let fileManager = FileManager.default
        let tempDirURL = fileManager.temporaryDirectory
        let calendar = Calendar.current

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: tempDirURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: []
            )
            
            for fileURL in fileURLs {
                let resourceValues = try fileURL.resourceValues(
                    forKeys: [.contentModificationDateKey]
                )
                
                if let modificationDate = resourceValues.contentModificationDate,
                   let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()),
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error cleaning temp directory: \(error)")
        }
    }
}

class Progress: ObservableObject {
    @Published var dict: [String: CGFloat] = [:]
    
    static let shared = Progress()
    
    func start(id: String) {
        dict[id] = 0
    }
    
    func complete(id: String) {
        dict[id] = 1
    }
    
    func update(id: String, rate: CGFloat) {
        dict[id] = rate
    }
    
    func remove(id: String) {
        dict.removeValue(forKey: id)
    }
    
    func isEmpty() -> Bool {
        return dict.values.count == 0
    }
    
    func clear() {
        dict.removeAll()
    }
    
    func size() -> Int {
        return dict.values.count
    }
    
    func completedRate() -> CGFloat {
        let totalTasks = size()
        guard totalTasks > 0 else { return 0 }
        let completedCount = dict.values.filter { $0 == 1 }.count
        return CGFloat(completedCount) / CGFloat(totalTasks)
    }
    
    func pendingRate() -> CGFloat {
        let totalTasks = size()
        guard totalTasks > 0 else { return 0 }
        let pendingSum = dict.values.filter { $0 < 1 }.reduce(0) { $0 + $1 }
        return pendingSum / CGFloat(totalTasks)
    }
    
    func totalRate() -> CGFloat {
        let totalTasks = size()
        guard totalTasks > 0 else { return 1 }
        let completed = dict.values.reduce(0) { $0 + $1 }
        return completed / CGFloat(totalTasks)
    }
    
    func toString() -> String {
        return "\(Int(totalRate() * CGFloat(size()))) / \(size())"
    }
    
    func keys() -> [String] {
        return Array(dict.keys)
    }
}

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer
    ) {
        print("Save finished!")
    }
}

func getHash(url: URL) -> String? {
    guard let data = try? Data(contentsOf: url) else {
        print("Failed to get hash from \(url)")
        return nil
    }
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}
