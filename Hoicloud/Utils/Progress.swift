//
//  Progress.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/1/25.
//

import Foundation

struct ProgressData: Codable {
    let id: String
    var rate: Double
    let startTime: Date
}

class Progress: ObservableObject {
    var key: String
    
    static let uploads = Progress("uploads")
    static let downloads = Progress("downloads")
    
    @Published var dict: [String: ProgressData] = [:] {
        didSet {
            do {
                let data = try JSONEncoder().encode(dict)
                UserDefaults.standard.set(data, forKey: "Progress_\(key)")
            } catch {
                print("Failed to encode progress data: \(error)")
            }
        }
    }
    
    init(_ key: String) {
        self.key = key
        guard let data = UserDefaults.standard.data(forKey: "Progress_\(key)") else { return }
        do {
            let decoded = try JSONDecoder().decode([String: ProgressData].self, from: data)
            self.dict = decoded
        } catch {
            print("Failed to decode progress data: \(error)")
        }
    }
    
    func start(id: String) {
        dict[id] = ProgressData(id: id, rate: 0, startTime: Date())
    }
    
    func complete(id: String) {
        if var data = dict[id] {
            data.rate = 1
            dict[id] = data
        }
        
    }
    
    func update(id: String, rate: CGFloat) {
        if var data = dict[id] {
            data.rate = rate
            dict[id] = data
        }
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
        let completedCount = dict.values.filter { $0.rate == 1 }.count
        return CGFloat(completedCount) / CGFloat(totalTasks)
    }
    
    func partiallyCompletedRate() -> CGFloat {
        let totalTasks = size()
        guard totalTasks > 0 else { return 0 }
        let pendingSum = dict.values.filter { $0.rate < 1 }.map(\.rate).reduce(0) { $0 + $1 }
        return pendingSum / CGFloat(totalTasks)
    }
    
    func overallRate() -> CGFloat {
        let totalTasks = size()
        guard totalTasks > 0 else { return 1 }
        let completed = dict.values.map(\.rate).reduce(0) { $0 + $1 }
        return completed / CGFloat(totalTasks)
    }
    
    func toString() -> String {
        let overall = overallRate()
        if size() == 0 {
            return "0"
        } else if overall == 1 {
            return String(size())
        } else {
            return "\(Int(overall * CGFloat(size()))) / \(size())"
        }
    }
    
    func keys() -> [String] {
        return Array(dict.keys)
    }
    
    func getRate(_ key: String) -> CGFloat {
        if let data = dict[key] {
            return data.rate
        }
        return 0
    }
    
    func getStartTime(_ key: String) -> Date? {
        if let data = dict[key] {
            return data.startTime
        }
        return nil
    }
}
