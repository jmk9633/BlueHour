//
//  DiaryEntryMapper.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation

enum DiaryEntryMapper {

    // MARK: - SD → Domain

    static func toDomain(_ sd: SDDiaryEntry) -> DiaryEntry {
        DiaryEntry(
            id: sd.id,
            date: sd.date,
            recording: sd.recording.map(toDomain),
            transcript: sd.transcript.map(toDomain),
            analysis: sd.analysis.map(toDomain),
            createdAt: sd.createdAt,
            updatedAt: sd.updatedAt
        )
    }

    static func toDomain(_ sd: SDVoiceRecording) -> VoiceRecording {
        VoiceRecording(
            id: sd.id,
            fileName: sd.fileName,
            duration: sd.duration,
            createdAt: sd.createdAt
        )
    }

    static func toDomain(_ sd: SDDiaryTranscript) -> DiaryTranscript {
        DiaryTranscript(
            originalText: sd.originalText,
            editedText: sd.editedText,
            languageCode: sd.languageCode,
            confidence: sd.confidence
        )
    }

    static func toDomain(_ sd: SDSkyAnalysis) -> SkyAnalysis {
        SkyAnalysis(
            weatherType: SkyWeatherType(rawValue: sd.weatherTypeRaw) ?? .cloudyNight,
            title: sd.title,
            summary: sd.summary,
            emotionKeywords: sd.emotionKeywords,
            mainTheme: sd.mainTheme,
            recoverySignal: sd.recoverySignal,
            tomorrowSentence: sd.tomorrowSentence,
            analyzedAt: sd.analyzedAt
        )
    }

    // MARK: - Domain → SD (신규 생성)

    static func toSD(_ entry: DiaryEntry) -> SDDiaryEntry {
        SDDiaryEntry(
            id: entry.id,
            date: entry.date,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            recording: entry.recording.map(toSD),
            transcript: entry.transcript.map(toSD),
            analysis: entry.analysis.map(toSD)
        )
    }

    static func toSD(_ recording: VoiceRecording) -> SDVoiceRecording {
        SDVoiceRecording(
            id: recording.id,
            fileName: recording.fileName,
            duration: recording.duration,
            createdAt: recording.createdAt
        )
    }

    static func toSD(_ transcript: DiaryTranscript) -> SDDiaryTranscript {
        SDDiaryTranscript(
            originalText: transcript.originalText,
            editedText: transcript.editedText,
            languageCode: transcript.languageCode,
            confidence: transcript.confidence
        )
    }

    static func toSD(_ analysis: SkyAnalysis) -> SDSkyAnalysis {
        SDSkyAnalysis(
            weatherTypeRaw: analysis.weatherType.rawValue,
            title: analysis.title,
            summary: analysis.summary,
            emotionKeywords: analysis.emotionKeywords,
            mainTheme: analysis.mainTheme,
            recoverySignal: analysis.recoverySignal,
            tomorrowSentence: analysis.tomorrowSentence,
            analyzedAt: analysis.analyzedAt
        )
    }

    // MARK: - Domain → SD (기존 업데이트, in-place)

    static func apply(_ entry: DiaryEntry, to sd: SDDiaryEntry) {
        sd.date = entry.date
        sd.updatedAt = entry.updatedAt

        // recording
        if let recording = entry.recording {
            if let existing = sd.recording {
                existing.fileName = recording.fileName
                existing.duration = recording.duration
                existing.createdAt = recording.createdAt
            } else {
                sd.recording = toSD(recording)
            }
        } else {
            sd.recording = nil
        }

        // transcript
        if let transcript = entry.transcript {
            if let existing = sd.transcript {
                existing.originalText = transcript.originalText
                existing.editedText = transcript.editedText
                existing.languageCode = transcript.languageCode
                existing.confidence = transcript.confidence
            } else {
                sd.transcript = toSD(transcript)
            }
        } else {
            sd.transcript = nil
        }

        // analysis
        if let analysis = entry.analysis {
            if let existing = sd.analysis {
                existing.weatherTypeRaw = analysis.weatherType.rawValue
                existing.title = analysis.title
                existing.summary = analysis.summary
                existing.emotionKeywords = analysis.emotionKeywords
                existing.mainTheme = analysis.mainTheme
                existing.recoverySignal = analysis.recoverySignal
                existing.tomorrowSentence = analysis.tomorrowSentence
                existing.analyzedAt = analysis.analyzedAt
            } else {
                sd.analysis = toSD(analysis)
            }
        } else {
            sd.analysis = nil
        }
    }
}
