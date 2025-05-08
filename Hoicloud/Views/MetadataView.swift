//
//  MetadataView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/27/24.
//

import SwiftUI

struct MetadataView: View {
    var photo: Metadata
    @ObservedObject private var storageApi = StorageApi.shared
    @Binding var show: Bool

    var body: some View {
        HStack {
            Button(action: {
                show = false
            }) {
                Image(systemName: "arrow.left")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
            Spacer()
        }
        
        let title = if photo.mime_type.starts(with: "image/") {
            "Photo Metadata"
        } else if photo.mime_type.starts(with: "video/") {
            "Video Metadata"
        } else {
            "File Metadata"
        }
        
        Text(title)
            .font(.system(size: 24, weight: .bold))
            .frame(alignment: .leading)
            .padding(.top, 10.0)
        
        List {
            Section {
                HStack(spacing: 0) {
                    Text("File Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(photo.filename)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    Text("MIME Type")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(photo.mime_type)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    Text("Created")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatISODate(photo.created))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    Text("Uploaded")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatISODate(photo.uploaded))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            Section {
                HStack(spacing: 0) {
                    Text("Width")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatSize(photo.width))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    Text("Height")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatSize(photo.height))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    Text("Duration")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatDuration(photo.duration))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            Section {
                HStack(spacing: 0) {
                    Text("Altitude")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatAltitude(photo.altitude))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    Text("Location")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(formatCoordinate(photo.latitude, photo.longitude))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            Section {
                Button(action: {
                    Task {
                        await storageApi.deleteFile(
                            photo: photo
                        )
                        show = false
                    }
                }) {
                    Text("Delete")
                        .foregroundColor(.red)
                }
                Button(action: {
                    show = false
                }) {
                    Text("Close")
                }
            }
        }
    }
    
    private let formatter1 = ISO8601DateFormatter()
    private let formatter2 = DateFormatter()
    
    private func formatISODate(_ dateString: String?) -> String {
        formatter1.formatOptions.insert(.withFractionalSeconds)
        guard let dateString else { return "Unknown" }
        guard let date = formatter1.date(from: dateString) else { return "Unknown" }
        formatter2.locale = Locale(identifier: "en_US")
        formatter2.dateStyle = .medium
        formatter2.timeStyle = .none
        let formattedDateString = formatter2.string(from: date)
        formatter2.dateStyle = .none
        formatter2.timeStyle = .short
        let formattedTimeString = formatter2.string(from: date)
        return formattedDateString + "\nat " + formattedTimeString
    }
    
    private func formatFloat(_ float: Float?) -> String? {
        guard let float else { return nil }
        return String(format: "%.2f", float)
    }
    
    private func formatDuration(_ duration: Float?) -> String {
        guard let duration, let string = formatFloat(duration) else { return "Unknown" }
        return string + " seconds"
    }
    
    private func formatAltitude(_ altidue: Float?) -> String {
        guard let altidue, let string = formatFloat(altidue) else { return "Unknown" }
        let sign = if altidue > 0 { "+" } else if altidue < 0 { "-" } else { "" }
        return sign + " " + string + " meters"
    }
    
    private func formatCoordinate(_ lat: Float?, _ lon: Float?) -> String {
        guard let lat, let lon else { return "Unknown" }
        return "\(formatFloat(lat)!)º North\n\(formatFloat(lon)!)º West"
    }
    
    private func formatSize(_ size: Int?) -> String {
        guard let string = size?.formatted() else { return "Unknown" }
        return string + " pixels"
    }
}
