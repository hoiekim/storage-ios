//
//  DiagonalStripes.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/1/25.
//

import SwiftUI

struct DiagonalStripesPattern: View {
    let color1: Color
    let color2: Color
    let lineWidth: CGFloat
    let spacing: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // Calculate how many stripes we need
            let totalWidth = size.width + size.height
            let stripeWidth = lineWidth + spacing
            let totalStripes = Int(totalWidth / stripeWidth) + 1
            
            // Draw diagonal stripes for both colors
            for i in 0..<totalStripes {
                // Position for the current stripe
                let startX = CGFloat(i) * stripeWidth - size.height
                
                // First color stripe
                let start1 = CGPoint(x: startX, y: size.height)
                let end1 = CGPoint(x: startX + size.height, y: 0)
                
                var path1 = Path()
                path1.move(to: start1)
                path1.addLine(to: end1)
                path1.addLine(to: CGPoint(x: end1.x + lineWidth, y: end1.y))
                path1.addLine(to: CGPoint(x: start1.x + lineWidth, y: start1.y))
                path1.closeSubpath()
                
                context.fill(path1, with: .color(color1))
                
                // Second color stripe (in the spacing area)
                let start2 = CGPoint(x: startX + lineWidth, y: size.height)
                let end2 = CGPoint(x: startX + lineWidth + size.height, y: 0)
                
                var path2 = Path()
                path2.move(to: start2)
                path2.addLine(to: end2)
                path2.addLine(to: CGPoint(x: end2.x + spacing, y: end2.y))
                path2.addLine(to: CGPoint(x: start2.x + spacing, y: start2.y))
                path2.closeSubpath()
                
                context.fill(path2, with: .color(color2))
            }
        }
        .allowsHitTesting(false) // Make sure it doesn't interfere with touch events
    }
}

// Extension for View to make it easier to use
extension View {
    func diagonalStripes(
        color1: Color = .white,
        color2: Color = .black,
        lineWidth: CGFloat = 10,
        spacing: CGFloat = 10
    ) -> some View {
        // Use a ZStack to ensure transparency works correctly
        ZStack {
            self.opacity(0) // Make the original view transparent
            DiagonalStripesPattern(
                color1: color1,
                color2: color2,
                lineWidth: lineWidth,
                spacing: spacing
            )
        }
    }
}
