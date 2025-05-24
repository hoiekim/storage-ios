//
//  FlowLayout.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/23/25.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading // supports: .leading, .center, .trailing

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = computeLines(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let height = lines.reduce(0) { $0 + $1.height } + CGFloat(max(0, lines.count - 1)) * lineSpacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let lines = computeLines(subviews: subviews, maxWidth: bounds.width)

        var y = bounds.minY

        for line in lines {
            let xOffset: CGFloat
            switch alignment {
            case .leading:
                xOffset = bounds.minX
            case .center:
                xOffset = bounds.minX + (bounds.width - line.width) / 2
            case .trailing:
                xOffset = bounds.maxX - line.width
            default:
                xOffset = bounds.minX
            }

            var x = xOffset
            for item in line.items {
                item.subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func computeLines(subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var currentLine = Line()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentLine.width + size.width + (currentLine.items.isEmpty ? 0 : spacing) > maxWidth {
                lines.append(currentLine)
                currentLine = Line()
            }
            currentLine.add(subview: subview, size: size, spacing: spacing)
        }

        if !currentLine.items.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    private struct Line {
        var items: [(subview: LayoutSubview, size: CGSize)] = []

        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func add(subview: LayoutSubview, size: CGSize, spacing: CGFloat) {
            if !items.isEmpty {
                width += spacing
            }
            items.append((subview, size))
            width += size.width
            height = max(height, size.height)
        }
    }
}
