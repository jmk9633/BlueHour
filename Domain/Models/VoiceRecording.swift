//
//  VoiceRecording.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

struct VoiceRecording: Identifiable, Equatable, Sendable {
    let id: UUID
    var fileName: String
    var duration: TimeInterval
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        duration: TimeInterval,
        createdAt: Date = .now
    ) {
        self.id = id
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
    }
}
