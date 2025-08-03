//
//  Item.swift
//  Links
//
//  Created by Thomas Andrew on 8/3/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
