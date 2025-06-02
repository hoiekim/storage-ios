//
//  VisionUtil.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/12/25.
//

import Vision
import PhotosUI
import SwiftUI

func extractLabels(from image: UIImage) async -> [String] {
    guard let cgImage = image.cgImage else { return [] }

    return await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            var didResume = false
            func resume(_ value: [String]) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let request = VNClassifyImageRequest { request, error in
                guard let results = request.results as? [VNClassificationObservation] else {
                    resume([])
                    return
                }

                let labels = results
                    .filter { $0.confidence > 0.5 }
                    .map { $0.identifier }

                resume(labels)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resume([])
            }
        }
    }
}

func extractLabels(from asset: PHAsset) async -> [String] {
    let image = await withCheckedContinuation { continuation in
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            guard !degraded else { return }
            continuation.resume(returning: image)
        }
    }
    
    if let image {
        return await extractLabels(from: image)
    } else {
        return []
    }
}

func extractLabels(from pickerItem: PhotosPickerItem) async -> [String] {
    do {
        if let data = try await pickerItem.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            return await extractLabels(from: image)
        }
    } catch {
        print("Failed to load image from PhotosPickerItem:", error)
    }
    return []
}
