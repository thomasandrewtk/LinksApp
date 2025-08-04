//
//  LinksApp.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI
import SwiftData

@main
struct LinksApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
        .modelContainer(for: GameCompletion.self) { result in
            do {
                let container = try result.get()
                
                // Configure the completion service with the model context
                Task { @MainActor in
                    GameCompletionService.shared.configure(with: container.mainContext)
                }
                
                print("✅ SwiftData container configured successfully")
            } catch {
                print("❌ Failed to configure SwiftData container: \(error)")
            }
        }
    }
}
