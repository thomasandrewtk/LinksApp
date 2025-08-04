//
//  NotificationManager.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation
import UserNotifications
import SwiftData
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - Constants
    private let maxScheduledDays = 30
    private let reminderHour = 15 // 3 PM
    private let newPuzzleHour = 0 // Midnight
    
    // MARK: - Notification Categories
    private let newPuzzleCategory = "NEW_PUZZLE"
    private let reminderCategory = "PUZZLE_REMINDER"
    
    // MARK: - Snarky Messages
    private let midnightMessages = [
        "🌙 Rise and grind! New Links have dropped.",
        "🎯 Fresh Links just landed. Don't disappoint me.",
        "🔥 New Links alert! Time to prove your worth.",
        "⚡ Daily brain teaser is live. Try not to embarrass yourself.",
        "🎪 New Links circus is in town. Step right up!",
        "🚀 Houston, we have new Links. Don't crash and burn.",
        "🎮 Level up time! New Links await your genius.",
        "💎 Premium Links content just dropped. You're welcome.",
        "🎲 Roll the dice on today's Links. Feeling lucky?",
        "🧩 Links assembly required. Intellect not included.",
        "⭐ Star player needed for today's Links. You up for it?",
        "🎊 Links party started without you. Fashionably late?",
        "🔮 Crystal ball says... new Links are available now!",
        "🎯 Bulls-eye! New target Links locked and loaded.",
        "🌟 Shine bright with today's stellar Links challenge."
    ]
    
    private let reminderMessages = [
        "😴 Still sleeping on today's Links? Wake up, champ!",
        "🏃‍♂️ Links are getting lonely. Show them some love.",
        "🤔 Today's Links called. They miss you terribly.",
        "😏 Avoiding today's Links won't make them disappear.",
        "🙄 Your Links are judging you right now. Just saying.",
        "😬 Links anxiety? Today's challenge is still waiting.",
        "🤨 Seriously? You're gonna ghost today's Links?",
        "😤 Today's Links are personally offended by your absence.",
        "🫤 Links are collecting dust. This is awkward.",
        "😵‍💫 Brain getting rusty? Polish it with today's Links.",
        "🤦‍♂️ Today's Links think you've forgotten about them.",
        "😒 Your daily Links game is weaker than yesterday's coffee.",
        "🙃 Plot twist: Today's Links are actually easy. Maybe.",
        "😑 Day's almost over and Links status: still ignored.",
        "🤷‍♂️ Today's Links wondering if you're even real anymore.",
        "😪 Today's Links are having an existential crisis without you.",
        "🎭 Drama alert: Your Links feel abandoned and betrayed.",
        "💔 Today's Links' hearts are breaking. Be the hero they need.",
        "🚨 Links emergency! Your brain cells are filing a complaint.",
        "🤡 Don't be a Links clown. Finish what you started... or didn't start."
    ]
    
    // MARK: - Persistent Storage Keys
    private let lastMidnightMessageKey = "lastMidnightMessage"
    private let lastReminderMessageKey = "lastReminderMessage"
    private let midnightMessageHistoryKey = "midnightMessageHistory"
    private let reminderMessageHistoryKey = "reminderMessageHistory"
    
    private init() {}
    
    // MARK: - Public Interface
    func requestPermissionAndSchedule() async {
        await requestNotificationPermission()
        await scheduleNotificationsIfNeeded()
    }
    
    func scheduleNotificationsIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        
        // Get currently scheduled notifications
        let pendingRequests = await center.pendingNotificationRequests()
        
        // Count how many days we have scheduled
        let midnightCount = pendingRequests.filter { $0.identifier.hasPrefix("midnight_") }.count
        let reminderCount = pendingRequests.filter { $0.identifier.hasPrefix("reminder_") }.count
        
        let daysToSchedule = maxScheduledDays - min(midnightCount, reminderCount)
        
        print("📅 Current scheduled notifications: \(midnightCount) midnight, \(reminderCount) reminder")
        print("📝 Need to schedule \(daysToSchedule) more days")
        
        if daysToSchedule > 0 {
            await scheduleNotifications(for: daysToSchedule)
        }
    }
    
    func cancelTodaysReminder() async {
        let center = UNUserNotificationCenter.current()
        let todayIdentifier = "reminder_\(todayDateString())"
        
        center.removePendingNotificationRequests(withIdentifiers: [todayIdentifier])
        print("🚫 Cancelled today's reminder notification")
    }
    
    func onGameCompleted() async {
        await cancelTodaysReminder()
        print("🎉 Game completed - reminder cancelled")
    }
    
    // MARK: - Permission Handling
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        } catch {
            print("❌ Error requesting notification permission: \(error)")
        }
    }
    
    // MARK: - Scheduling Logic
    private func scheduleNotifications(for days: Int) async {
        let calendar = Calendar.current
        let now = Date()
        
        // Find the starting point - either tomorrow or the day after the last scheduled notification
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        var startDate: Date
        if !pendingRequests.isEmpty {
            // Find the latest scheduled date and start from the day after
            let latestDate = pendingRequests.compactMap { request -> Date? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let triggerDate = trigger.nextTriggerDate() else { return nil }
                return triggerDate
            }.max()
            
            if let latest = latestDate {
                startDate = calendar.date(byAdding: .day, value: 1, to: latest) ?? calendar.date(byAdding: .day, value: 1, to: now)!
            } else {
                startDate = calendar.date(byAdding: .day, value: 1, to: now)!
            }
        } else {
            // No notifications scheduled, start from tomorrow
            startDate = calendar.date(byAdding: .day, value: 1, to: now)!
        }
        
        // Get message history to avoid repeats
        var midnightHistory = UserDefaults.standard.stringArray(forKey: midnightMessageHistoryKey) ?? []
        var reminderHistory = UserDefaults.standard.stringArray(forKey: reminderMessageHistoryKey) ?? []
        
        for dayOffset in 0..<days {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            
            let dateString = dateString(from: targetDate)
            
            // Schedule midnight notification
            let midnightMessage = getNextMessage(
                from: midnightMessages,
                excluding: midnightHistory,
                historyKey: midnightMessageHistoryKey
            )
            midnightHistory.append(midnightMessage)
            
            await scheduleNotification(
                identifier: "midnight_\(dateString)",
                title: "🔗 Links",
                body: midnightMessage,
                date: targetDate,
                hour: newPuzzleHour,
                category: newPuzzleCategory
            )
            
            // Schedule 3PM reminder notification
            let reminderMessage = getNextMessage(
                from: reminderMessages,
                excluding: reminderHistory,
                historyKey: reminderMessageHistoryKey
            )
            reminderHistory.append(reminderMessage)
            
            await scheduleNotification(
                identifier: "reminder_\(dateString)",
                title: "🤔 Puzzle Procrastinating?",
                body: reminderMessage,
                date: targetDate,
                hour: reminderHour,
                category: reminderCategory
            )
        }
        
        // Update history in UserDefaults (keep last 20 to manage memory)
        UserDefaults.standard.set(Array(midnightHistory.suffix(20)), forKey: midnightMessageHistoryKey)
        UserDefaults.standard.set(Array(reminderHistory.suffix(20)), forKey: reminderMessageHistoryKey)
        
        print("✅ Scheduled \(days) days of notifications")
    }
    
    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        date: Date,
        hour: Int,
        category: String
    ) async {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 Scheduled notification: \(identifier) for \(dateString(from: date)) at \(hour):00")
        } catch {
            print("❌ Failed to schedule notification \(identifier): \(error)")
        }
    }
    
    // MARK: - Message Selection Logic
    private func getNextMessage(from messages: [String], excluding history: [String], historyKey: String) -> String {
        // If we've used all messages, reset history and start fresh
        if Set(history).count >= messages.count {
            UserDefaults.standard.set([], forKey: historyKey)
            return messages.randomElement() ?? messages[0]
        }
        
        // Get messages we haven't used recently
        let availableMessages = messages.filter { !history.suffix(5).contains($0) }
        
        if availableMessages.isEmpty {
            // Fallback to any message if somehow we have no available ones
            return messages.randomElement() ?? messages[0]
        }
        
        return availableMessages.randomElement() ?? availableMessages[0]
    }
    
    // MARK: - Utility Methods
    private func todayDateString() -> String {
        return dateString(from: Date())
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Debug Methods
    func printScheduledNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        print("📋 Currently scheduled notifications:")
        for request in pendingRequests.sorted(by: { 
            ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? Date() < 
            ($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? Date()
        }) {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let triggerDate = trigger.nextTriggerDate() {
                print("  \(request.identifier): \(triggerDate)")
            }
        }
    }
    
    func clearAllNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Clear message history
        UserDefaults.standard.removeObject(forKey: midnightMessageHistoryKey)
        UserDefaults.standard.removeObject(forKey: reminderMessageHistoryKey)
        
        print("🧹 Cleared all notifications and message history")
    }
}
