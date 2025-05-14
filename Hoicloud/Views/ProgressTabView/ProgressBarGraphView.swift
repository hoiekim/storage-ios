//
//  ProgressBar.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/11/25.
//

import SwiftUI

struct ProgressBarGraphView: View {
    @ObservedObject var progress: Progress
    
    var body: some View {
        VStack {
            HStack {
                Text("Total progress")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 14))
                Text(progress.toString())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .diagonalStripes(
                            color1: .gray.opacity(0.15),
                            color2: .black.opacity(0.15),
                            lineWidth: 5,
                            spacing: 5
                        )
                    if !progress.isEmpty() {
                        let barWidth = geometry.size.width
                        let completed = barWidth * progress.completedRate()
                        let partial = barWidth * progress.partiallyCompletedRate()
                        let pending = barWidth * (1 - progress.overallRate())
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(.indigo)
                                .frame(width: completed)
                            Rectangle()
                                .fill(.blue)
                                .frame(width: partial)
                            Rectangle()
                                .fill(.gray)
                                .frame(width: pending)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .cornerRadius(2)
            }
            .frame(height: 10)
            .animation(.linear, value: progress.overallRate())
            .padding(.bottom, 8)
            
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.indigo)
                        .frame(width: 8, height: 8)
                    Text("Completed")
                        .font(.system(size: 10))
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    Text("Processing")
                        .font(.system(size: 10))
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(.gray)
                        .frame(width: 8, height: 8)
                    Text("Queued")
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

