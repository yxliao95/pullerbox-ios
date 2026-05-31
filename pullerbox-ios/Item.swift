//
//  Item.swift
//  pullerbox-ios
//
//  Created by Yuxiang Liao on 2026/5/31.
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
