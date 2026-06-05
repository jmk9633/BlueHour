//
//  DiaryEntry.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

struct DiaryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    var date: Date              // 일기의 "하루" (자정 기준 정규화)
    var recording: VoiceRecording?
    var transcript: DiaryTranscript?
    var analysis: SkyAnalysis?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        recording: VoiceRecording? = nil,
        transcript: DiaryTranscript? = nil,
        analysis: SkyAnalysis? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.recording = recording
        self.transcript = transcript
        self.analysis = analysis
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var hasAnalysis: Bool { analysis != nil }
}
