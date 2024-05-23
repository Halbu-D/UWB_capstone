//
//  Feedback.swift
//  uwbapp
//
//  Created by Halbu on 4/27/24.
//

import Foundation
import CoreHaptics
import AudioToolbox
import os.log

// Base struct for the feedback array implementing three different feedback levels
struct FeedbackLevel {
    var hummDuration: TimeInterval
    var timerIndexRef: Int
}

class Feedback {
    // Auxiliary variables for feedback
    var engine: CHHapticEngine?
    var timerIndex: Int = 0
    var shortDistance: Float = 1.0
    var longDistance: Float = 3.0
    var feedbackLevel: Int = 0
    var feedbackLevelOld: Int = 0
    var feedbackPar: [FeedbackLevel] = [FeedbackLevel(hummDuration: 1.0, timerIndexRef: 8),
                                        FeedbackLevel(hummDuration: 0.5, timerIndexRef: 4),
                                        FeedbackLevel(hummDuration: 0.1, timerIndexRef: 1)]
    
    let logger = os.Logger(subsystem: "com.capstone.uwbapp", category: "Feedback")
    
    func update() {
        // As the timer is fast timerIndex and timerIndexRef provides a
        // pre-scaler to achieve different patterns
        if  timerIndex != feedbackPar[feedbackLevel].timerIndexRef {
            timerIndex += 1
            return
        }
        
        timerIndex = 0
        
        // Handles Sound, if enabled
        let systemSoundID: SystemSoundID = 1052
        AudioServicesPlaySystemSound(systemSoundID)
        
        // Handles Haptic, if enabled
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        var events = [CHHapticEvent]()
        
        let humm = CHHapticEvent(eventType: .hapticContinuous,
                                 parameters: [],
                                 relativeTime: 0,
                                 duration: feedbackPar[feedbackLevel].hummDuration)
        events.append(humm)
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            logger.info("Failed to play pattern: \(error.localizedDescription).")
        }
    }
    
    func setLevel(distance: Float) {
        // Select feedback Level according to the distance
        if distance > longDistance {
            feedbackLevel = 0
        }
        else if distance > shortDistance {
            feedbackLevel = 1
        }
        else {
            feedbackLevel = 2
        }
        
        // If level changes, apply immediately
        if feedbackLevel != feedbackLevelOld {
            timerIndex = 0
            feedbackLevelOld = feedbackLevel
        }
    }
    
    func setDistanceThresholds(_ newShortDistance: Float,_ newLongDistance: Float) {
        shortDistance = newShortDistance
        longDistance = newLongDistance
    }
}
