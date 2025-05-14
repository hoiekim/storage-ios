//
//  HoicloudApp.swift
//  Hoicloud
//
//  Created by Hoie Kim on 11/25/24.
//

import SwiftUI
import UIKit
import BackgroundTasks

@main
struct HoicloudApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private let SYNC_TASK_ID = "kim.hoie.Hoicloud.sync"

class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("Registering background task with identifier: \(SYNC_TASK_ID)")
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SYNC_TASK_ID,
            using: DispatchQueue.global()
        ) { [weak self] task in
            print("Background task handler called!")
            guard let self = self else { return }
            self.handlePhotoSyncTask(task: task as! BGProcessingTask)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            print("Pending background task requests at launch: \(requests)")
        }

        print("Cleaning temporary directory")
        cleanTemporaryDirectory(olderThan: 2)
        
        return true
    }
    
    @objc func appMovedToBackground() {
        scheduleBackgroundPhotoSync()
    }
    
    func scheduleBackgroundPhotoSync() {
        print("Attempting to schedule background task...")
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: SYNC_TASK_ID)
        
        do {
            let request = BGProcessingTaskRequest(identifier: SYNC_TASK_ID)
            request.requiresNetworkConnectivity = true
            // For testing, don't require external power
            request.requiresExternalPower = false
            
            // Set earliest begin date to a very short time for testing
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15)
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background task scheduled successfully")
        } catch {
            print("❌ Failed to submit background task: \(error)")
            
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error description: \(nsError.localizedDescription)")
            }
        }
    }

    private func handlePhotoSyncTask(task: BGProcessingTask) {
        print("🔄 Background task started - executing sync operation")
        
        let taskID = UUID()
        print("Background task ID: \(taskID)")
        
        task.expirationHandler = {
            print("⚠️ Background task \(taskID) expired")
        }
        
        Task {
            print("Starting sync operation for task \(taskID)...")
            await SyncUtil.shared.start(recursively: false)
            print("✅ Sync operation completed for task \(taskID)")
            
            task.setTaskCompleted(success: true)
            
            print("Scheduling next background task after \(taskID)...")
            self.scheduleBackgroundPhotoSync()
        }
    }
    
    // For debugging: Launch the app in background mode
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Background fetch called")
        scheduleBackgroundPhotoSync()
        completionHandler(.newData)
    }
}
