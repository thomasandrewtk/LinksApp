//
//  LinksApp.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import SwiftUI

@main
struct LinksApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .onAppear {
                    // Fetch today's puzzle on app launch
                    Task {
                        await PuzzleService.shared.fetchTodaysPuzzle()
                    }
                }
        }
    }
}
