//
//  BlueHourExportFormat.swift
//  BlueHour
//
//  데이터 내보내기(F-NJSTGI)·기록 가져오기(F-XXQNPA)에서 쓰는 교환 포맷.
//  ZIP 안에는 복원용 bluehour.json과 읽기용 블루아워_기록.txt, 음성 recordings/ 가 들어간다.
//  bluehour.json은 블루아워 자체 포맷이며 formatVersion=1 이다.
//

import Foundation

// MARK: - 내보내기/가져오기 공통 상수·오류

enum DataTransfer {
    /// 현재 bluehour.json 포맷 버전. 이 값과 다르면 가져올 수 없다.
    static let currentFormatVersion = 1

    /// ZIP 내부 파일명
    static let jsonFileName = "bluehour.json"
    static let readableTextFileName = "블루아워_기록.txt"
    static let recordingsFolderName = "recordings"

    /// 복원 시 재분석을 피하려고 JSON·텍스트의 날짜는 ISO8601로 쓴다.
    static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 내보내기 ZIP 파일명: '블루아워_{yyyy-MM-dd}.zip'
    static func exportFileName(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "블루아워_\(formatter.string(from: date)).zip"
    }
}

/// 데이터 전송 중 발생할 수 있는 오류.
enum DataTransferError: Error, Equatable {
    /// 내보낼 기록이 하나도 없음.
    case noEntries
    /// 블루아워 형식이 아니거나, 손상되었거나, 알 수 없는 formatVersion.
    case cannotImport
}

// MARK: - bluehour.json DTO

struct ExportDocument: Codable, Equatable, Sendable {
    var formatVersion: Int
    var appVersion: String
    var exportedAt: Date
    var entries: [ExportEntry]
}

struct ExportEntry: Codable, Equatable, Sendable {
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    var originalText: String?
    var editedText: String?
    var languageCode: String?
    var confidence: Double?
    /// 아직 그려지지 않은 하늘이면 nil.
    var analysis: ExportAnalysis?
    /// recordings/ 안의 파일명(예: "UUID.m4a"). 목소리가 없으면 nil.
    var audioFileName: String?
    var audioDuration: Double?
    var audioCreatedAt: Date?
}

struct ExportAnalysis: Codable, Equatable, Sendable {
    var weatherType: String
    var title: String
    var summary: String
    var emotionKeywords: [String]
    var mainTheme: String?
    var recoverySignal: String?
    var tomorrowSentence: String
    var analyzedAt: Date
}

// MARK: - 도메인 ↔ DTO 변환

extension ExportEntry {

    /// 도메인 기록을 내보내기 DTO로 변환한다.
    /// - Parameter includeVoice: '목소리도 함께 담기'가 켜져 있을 때만 음성 파일명을 담는다.
    init(entry: DiaryEntry, includeVoice: Bool) {
        self.date = entry.date
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
        self.originalText = entry.transcript?.originalText
        self.editedText = entry.transcript?.editedText
        self.languageCode = entry.transcript?.languageCode
        self.confidence = entry.transcript?.confidence
        self.analysis = entry.analysis.map(ExportAnalysis.init(analysis:))

        if includeVoice, let recording = entry.recording {
            self.audioFileName = recording.fileName
            self.audioDuration = recording.duration
            self.audioCreatedAt = recording.createdAt
        } else {
            self.audioFileName = nil
            self.audioDuration = nil
            self.audioCreatedAt = nil
        }
    }

    /// 읽기용 텍스트에 쓸 표시 텍스트(수정본 우선).
    var displayText: String {
        editedText ?? originalText ?? ""
    }

    /// 가져오기 시 복원할 DiaryTranscript. 원문이 없으면 nil.
    func makeTranscript() -> DiaryTranscript? {
        guard let originalText else { return nil }
        return DiaryTranscript(
            originalText: originalText,
            editedText: editedText,
            languageCode: languageCode ?? "ko-KR",
            confidence: confidence
        )
    }
}

extension ExportAnalysis {

    init(analysis: SkyAnalysis) {
        self.weatherType = analysis.weatherType.rawValue
        self.title = analysis.title
        self.summary = analysis.summary
        self.emotionKeywords = analysis.emotionKeywords
        self.mainTheme = analysis.mainTheme
        self.recoverySignal = analysis.recoverySignal
        self.tomorrowSentence = analysis.tomorrowSentence
        self.analyzedAt = analysis.analyzedAt
    }

    /// 가져오기 시 복원할 SkyAnalysis. weatherType이 알 수 없는 값이면 nil(형식 오류로 처리).
    func makeAnalysis() -> SkyAnalysis? {
        guard let type = SkyWeatherType(rawValue: weatherType) else { return nil }
        return SkyAnalysis(
            weatherType: type,
            title: title,
            summary: summary,
            emotionKeywords: emotionKeywords,
            mainTheme: mainTheme,
            recoverySignal: recoverySignal,
            tomorrowSentence: tomorrowSentence,
            analyzedAt: analyzedAt
        )
    }
}

// MARK: - 읽기용 텍스트

enum ReadableTextBuilder {

    /// 날짜순으로 날씨 이름·제목·요약·원문을 적는다.
    /// 아직 그려지지 않은 하늘은 날씨 이름 대신 '아직 그려지지 않은 하늘'로 적고 원문만 적는다.
    static func build(entries: [ExportEntry]) -> String {
        let sorted = entries.sorted { $0.date < $1.date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"

        var blocks: [String] = ["블루아워 기록"]

        for entry in sorted {
            var lines: [String] = [formatter.string(from: entry.date)]
            if let analysis = entry.analysis,
               let type = SkyWeatherType(rawValue: analysis.weatherType) {
                lines.append("날씨: \(type.displayName)")
                lines.append("제목: \(analysis.title)")
                lines.append("요약: \(analysis.summary)")
                lines.append("원문: \(entry.displayText)")
            } else {
                lines.append("아직 그려지지 않은 하늘")
                lines.append("원문: \(entry.displayText)")
            }
            blocks.append(lines.joined(separator: "\n"))
        }

        return blocks.joined(separator: "\n\n") + "\n"
    }
}
