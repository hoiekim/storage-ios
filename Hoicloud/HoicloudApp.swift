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

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("registering background task")
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SYNC_TASK_ID,
            using: nil
        ) { task in
            self.handlePhotoSyncTask(task: task as! BGProcessingTask)
        }
        
        
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            print("Pending background task requests: \(requests)")
        }

        print("cleaning temporary directory")
        cleanTemporaryDirectory(olderThan: 2)
        
        return true
    }
    
    // Called when the app enters the background
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundPhotoSync()
    }
    
    func scheduleBackgroundPhotoSync() {
        // Cancel any existing task with the same identifier
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: SYNC_TASK_ID)
        
        let request = BGProcessingTaskRequest(identifier: SYNC_TASK_ID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        // Set earliest begin date to ensure the task doesn't run immediately
        // This helps avoid the "app in foreground" error
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled successfully")
        } catch {
            print("Failed to submit background task: \(error)")
        }
    }

    private func handlePhotoSyncTask(task: BGProcessingTask) {
        let operation = BlockOperation {
            SyncUtil.shared.start()
        }

        task.expirationHandler = {
            operation.cancel()
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        OperationQueue().addOperation(operation)
    }
    
}
