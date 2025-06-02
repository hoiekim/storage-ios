//
//  LabelsView.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/29/25.
//

import SwiftUI

struct LabelsView: View {
    @ObservedObject private var storageApi = StorageApi.shared
    @Binding var selectedLabels: [String]
    
    @State private var labelsCount: [String: Int] = [:]
    
    @State private var labels: [String] = []
    
    var body: some View {
        if !labels.isEmpty {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .center, spacing: 10) {
                    ForEach(labels, id: \.self) { label in
                        let button = renderButton(label)
                        if selectedLabels.contains(label) {
                            button
                                .foregroundColor(Color(.placeholderText))
                                .background(Color(.systemFill))
                                .cornerRadius(8)
                        } else {
                            button
                                .foregroundColor(.primary)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: storageApi.labels) {
                sortLabels()
            }
            .onChange(of: selectedLabels) {
                sortLabels()
            }
        } else if !storageApi.labels.isEmpty {
            Color
                .clear
                .onAppear {
                    sortLabels()
                }
        }
    }
    
    @ViewBuilder
    private func renderButton(_ label: String) -> some View {
        let count = labelsCount[label] ?? 0
        
        Button(action: {
            if selectedLabels.contains(label) {
                selectedLabels.removeAll { $0 == label }
            } else {
                selectedLabels.append(label)
            }
        }) {
            if count > 0 {
                Text("\(label) (\(count))")
                    .font(.system(size: 20))
            } else {
                Text(label)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
    
    @State private var sortTask: Task<Void, Never>?
    
    func sortLabels() {
        sortTask?.cancel()
        sortTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            
            let labelsArray = storageApi.labels.values
            let set = labelsArray.reduce(into: Set<String>()) { result, labels in
                for label in labels {
                    result.insert(label)
                }
            }
            
            var labelsCount: [String: Int] = [:]
            for labels in storageApi.labels.values {
                for label in labels {
                    if let existing = labelsCount[label] {
                        labelsCount[label] = existing + 1
                    } else {
                        labelsCount[label] = 0
                    }
                }
            }
            
            let labels = Array(set).sorted {
                if selectedLabels.contains($0) && !selectedLabels.contains($1) {
                    return true
                } else if !selectedLabels.contains($0) && selectedLabels.contains($1) {
                    return false
                } else {
                    let count0 = labelsCount[$0] ?? 0
                    let count1 = labelsCount[$1] ?? 0
                    return count0 > count1
                }
            }
            
            DispatchQueue.main.async {
                self.labelsCount = labelsCount
                self.labels = labels
            }
        }
    }
}
