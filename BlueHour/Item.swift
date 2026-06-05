//
//  Item.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
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
