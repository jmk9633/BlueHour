//
//  SDDiaryEntry.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

@Model
final class SDDiaryEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var recording: SDVoiceRecording?

    @Relationship(deleteRule: .cascade)
    var transcript: SDDiaryTranscript?

    @Relationship(deleteRule: .cascade)
    var analysis: SDSkyAnalysis?

    init(
        id: UUID,
        date: Date,
        createdAt: Date,
        updatedAt: Date,
        recording: SDVoiceRecording? = nil,
        transcript: SDDiaryTranscript? = nil,
        analysis: SDSkyAnalysis? = nil
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recording = recording
        self.transcript = transcript
        self.analysis = analysis
    }
}
