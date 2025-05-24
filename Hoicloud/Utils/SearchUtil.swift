//
//  SearchBar.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/20/25.
//

import SwiftUI

// Levenshtein distance algorithm for fuzzy matching
func levenshteinDistance(from source: String, to target: String) -> Double {
    let source = source.lowercased()
    let target = target.lowercased()
    
    let sourceCount = source.count
    let targetCount = target.count
    
    // Create a 2D array to store distances
    var distanceMatrix = Array(repeating: Array(repeating: 0, count: targetCount + 1), count: sourceCount + 1)
    
    // Initialize the first row and column
    for i in 0...sourceCount {
        distanceMatrix[i][0] = i
    }
    
    for j in 0...targetCount {
        distanceMatrix[0][j] = j
    }
    
    // Fill the matrix
    for i in 1...sourceCount {
        for j in 1...targetCount {
            let sourceIndex = source.index(source.startIndex, offsetBy: i - 1)
            let targetIndex = target.index(target.startIndex, offsetBy: j - 1)
            
            let cost = source[sourceIndex] == target[targetIndex] ? 0 : 1
            
            distanceMatrix[i][j] = min(
                distanceMatrix[i-1][j] + 1,          // deletion
                distanceMatrix[i][j-1] + 1,          // insertion
                distanceMatrix[i-1][j-1] + cost      // substitution
            )
        }
    }
    
    // Calculate raw distance
    let distance = distanceMatrix[sourceCount][targetCount]
    
    // Normalize to 0-1 range by dividing by the maximum possible distance
    // (which is the length of the longer string)
    let maxPossibleDistance = max(sourceCount, targetCount)
    
    // Avoid division by zero
    if maxPossibleDistance == 0 {
        return 0.0 // Both strings are empty, so they're identical
    }
    
    // Return normalized distance (0 = identical, 1 = completely different)
    return Double(distance) / Double(maxPossibleDistance)
}

// Get match score between two strings using Levenshtein distance
func getMatchScore(string: String, to searchTerm: String) -> Double {
    // Calculate single score for the full strings
    let distance = levenshteinDistance(from: string, to: searchTerm)
    return 1.0 - distance
}
