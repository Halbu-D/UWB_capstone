//
//  NotificationManager.swift
//  uwbapp
//
//  Created by Halbu on 4/28/24.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let instance = NotificationManager()
    
    func requestAuthorization(){
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            (granted, error) in guard granted else {return}
        }
    }
    
    func setNotification(deviceName: String, deviceMessage: String) {
        let content = UNMutableNotificationContent()
        
        content.title = "UWB기기 \(deviceName)"
        content.subtitle = "\(deviceMessage)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(identifier: "UWB Background", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
