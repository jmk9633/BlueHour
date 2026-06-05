//
//  SDVoiceRecording.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

@Model
final class SDVoiceRecording {
    var id: UUID
    var fileName: String
    var duration: TimeInterval
    var createdAt: Date

    init(id: UUID, fileName: String, duration: TimeInterval, createdAt: Date) {
        self.id = id
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
    }
}
