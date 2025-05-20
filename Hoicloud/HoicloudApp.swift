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

class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        BackgroundUtil.registerBackgroundTask()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        print("Cleaning temporary directory")
        cleanTemporaryDirectory(olderThan: 2)
        
        return true
    }
    
    @objc func appMovedToBackground() {
        BackgroundUtil.scheduleBackgroundTask()
    }
    
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("Background fetch called")
        BackgroundUtil.scheduleBackgroundTask()
        completionHandler(.newData)
    }
}
