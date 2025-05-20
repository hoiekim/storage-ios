//
//  BackgroundUtil.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/17/25.
//

import BackgroundTasks


class BackgroundUtil {
    static let SYNC_TASK_ID = "kim.hoie.Hoicloud.sync"
    
    static func registerBackgroundTask() {
        print("Registering background task with identifier: \(SYNC_TASK_ID)")
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SYNC_TASK_ID,
            using: DispatchQueue.global()
        ) { task in
            print("Background task handler called!")
            cleanTemporaryDirectory(olderThan: 2)
            handlePhotoSyncTask(task: task as! BGProcessingTask)
        }
    }
    
    static func handlePhotoSyncTask(task: BGProcessingTask) {
        print("🔄 Background task started - executing sync operation")
        
        let taskID = UUID()
        print("Background task ID: \(taskID)")
        
        task.expirationHandler = {
            print("⚠️ Background task \(taskID) expired")
            scheduleBackgroundTask()
        }
        
        Task {
            print("Starting sync operation for task \(taskID)...")
            await SyncUtil.shared.start(recursively: false)
            print("✅ Sync operation completed for task \(taskID)")
            task.setTaskCompleted(success: true)
            scheduleBackgroundTask()
        }
    }
    
    static func scheduleBackgroundTask() {
        print("Attempting to schedule background task...")
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: SYNC_TASK_ID)
        
        do {
            let request = BGProcessingTaskRequest(identifier: SYNC_TASK_ID)
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = true
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
}
