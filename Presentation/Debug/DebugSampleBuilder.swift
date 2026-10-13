//
//  DebugSampleBuilder.swift
//  BlueHour
//
//  DEBUG 전용: 샘플 기록(#2)과 가져오기용 샘플 ZIP(#10)을 만든다.
//  기록 '생성' 로직은 순수 함수(repository·파일 I/O와 분리)로 두어 테스트할 수 있게 한다.
//

#if DEBUG
import Foundation
import AVFoundation
import ZIPFoundation

/// 샘플 묶음 종류.
enum DebugSeedKind: String, CaseIterable {
    case weather10  // 날씨 10종 (어제부터 10일)
    case month      // 한 달 채우기 (지난달 + 이번 달 일부)
    case undrawn    // 아직 그려지지 않은 하늘 3개
    case voice      // 목소리 있는 기록 1개

    var label: String {
        switch self {
        case .weather10: return "날씨 10종 (어제부터 10일)"
        case .month: return "한 달 채우기"
        case .undrawn: return "그려지지 않은 하늘 3개"
        case .voice: return "목소리 있는 기록 1개"
        }
    }
}

/// 가져오기용 샘플 ZIP 종류.
enum DebugZipKind: String, CaseIterable {
    case normal          // 정상
    case overlap         // 현재 기록과 날짜 겹침
    case badVersion      // formatVersion 99
    case corrupt         // 손상(잘린 JSON)
    case missingAudio    // JSON에는 음성이 있는데 recordings/ 없음

    var label: String {
        switch self {
        case .normal: return "정상"
        case .overlap: return "날짜 겹침"
        case .badVersion: return "formatVersion 99"
        case .corrupt: return "손상(잘린 JSON)"
        case .missingAudio: return "음성 누락"
        }
    }
    var fileName: String { "sample-\(rawValue).zip" }
}

struct DebugSeedResult: Equatable {
    var inserted: Int
    var skipped: Int
}

enum DebugSampleBuilder {

    // MARK: - 순수 생성 (테스트 대상)

    private static var calendar: Calendar { .current }

    /// 어제부터 10일, 날씨 10종을 하루에 하나씩. (오늘 제외)
    static func weather10Entries(now: Date = BlueHourClock.now()) -> [DiaryEntry] {
        let today = BlueHourCalendar.startOfLogicalDay(for: now, calendar: calendar)
        return SkyWeatherType.allCases.enumerated().map { index, weather in
            let day = calendar.date(byAdding: .day, value: -(index + 1), to: today) ?? today
            return makeEntry(date: day, weather: weather)
        }
    }

    /// 한 달 채우기: 지난달 전체 + 이번 달 1일~어제. 날씨를 고루 섞는다. (오늘·미래 제외)
    static func monthEntries(now: Date = BlueHourClock.now()) -> [DiaryEntry] {
        let today = BlueHourCalendar.startOfLogicalDay(for: now, calendar: calendar)
        var days: [Date] = []

        // 지난달 전체
        if let firstOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
           let lastMonthDay = calendar.date(byAdding: .month, value: -1, to: firstOfThisMonth),
           let range = calendar.range(of: .day, in: .month, for: lastMonthDay),
           let lastMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDay)) {
            for offset in range {
                if let day = calendar.date(byAdding: .day, value: offset - 1, to: lastMonthStart) {
                    days.append(calendar.startOfDay(for: day))
                }
            }
        }

        // 이번 달 1일 ~ 어제 (오늘 제외)
        if let firstOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) {
            var day = firstOfThisMonth
            while day < today {
                days.append(calendar.startOfDay(for: day))
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? today
            }
        }

        let weathers = SkyWeatherType.allCases
        return days.enumerated().map { index, day in
            makeEntry(date: day, weather: weathers[index % weathers.count])
        }
    }

    /// 아직 그려지지 않은 하늘 3개 (analysis 없음). 11~13일 전.
    static func undrawnEntries(now: Date = BlueHourClock.now()) -> [DiaryEntry] {
        let today = BlueHourCalendar.startOfLogicalDay(for: now, calendar: calendar)
        return (11...13).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return DiaryEntry(
                date: day,
                transcript: DiaryTranscript(originalText: "오늘은 그냥 조용히 하루를 보냈어요. 특별한 일은 없었지만 나쁘지 않았어요."),
                analysis: nil,
                createdAt: day,
                updatedAt: day
            )
        }
    }

    /// 샘플 기록 하나 조립(분석 포함).
    static func makeEntry(date: Date, weather: SkyWeatherType) -> DiaryEntry {
        let content = sampleContent(for: weather)
        return DiaryEntry(
            date: date,
            transcript: DiaryTranscript(originalText: content.original),
            analysis: SkyAnalysis(
                weatherType: weather,
                title: content.title,
                summary: content.summary,
                emotionKeywords: content.keywords,
                mainTheme: content.theme,
                recoverySignal: content.recovery,
                tomorrowSentence: content.tomorrow,
                analyzedAt: date
            ),
            createdAt: date,
            updatedAt: date
        )
    }

    // MARK: - 저장 (I/O)

    /// 묶음을 저장한다. 같은 날짜에 이미 기록이 있으면 건너뛴다.
    static func seed(_ kind: DebugSeedKind, into di: DIContainer) async throws -> DebugSeedResult {
        switch kind {
        case .weather10:
            return try await save(weather10Entries(), repository: di.diaryRepository)
        case .month:
            return try await save(monthEntries(), repository: di.diaryRepository)
        case .undrawn:
            return try await save(undrawnEntries(), repository: di.diaryRepository)
        case .voice:
            return try await seedVoice(repository: di.diaryRepository, fileStore: di.audioService)
        }
    }

    /// 같은 날짜에 이미 기록이 있으면 건너뛰고, 넣은 수·건너뛴 수를 돌려준다. (무료 카운트와 무관)
    static func save(
        _ entries: [DiaryEntry],
        repository: DiaryRepositoryProtocol
    ) async throws -> DebugSeedResult {
        var inserted = 0, skipped = 0
        for entry in entries {
            if (try? await repository.fetchEntry(on: entry.date)) != nil {
                skipped += 1
            } else {
                try await repository.save(entry)
                inserted += 1
            }
        }
        return DebugSeedResult(inserted: inserted, skipped: skipped)
    }

    /// 목소리 있는 기록 1개: 5초 무음 m4a를 만들어 Recordings에 넣고 연결한다. (14일 전)
    static func seedVoice(
        repository: DiaryRepositoryProtocol,
        fileStore: RecordingFileStoring
    ) async throws -> DebugSeedResult {
        let today = BlueHourCalendar.startOfLogicalDay(for: BlueHourClock.now(), calendar: calendar)
        let day = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        if (try? await repository.fetchEntry(on: day)) != nil {
            return DebugSeedResult(inserted: 0, skipped: 1)
        }

        let tempURL = try makeSilentM4A(seconds: 5)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let fileName = try await fileStore.copyIntoRecordings(from: tempURL)

        let content = sampleContent(for: .moonlight)
        let entry = DiaryEntry(
            date: day,
            recording: VoiceRecording(fileName: fileName, duration: 5, createdAt: day),
            transcript: DiaryTranscript(originalText: content.original),
            analysis: SkyAnalysis(
                weatherType: .moonlight,
                title: content.title,
                summary: content.summary,
                emotionKeywords: content.keywords,
                mainTheme: content.theme,
                recoverySignal: content.recovery,
                tomorrowSentence: content.tomorrow,
                analyzedAt: day
            ),
            createdAt: day,
            updatedAt: day
        )
        try await repository.save(entry)
        return DebugSeedResult(inserted: 1, skipped: 0)
    }

    /// 5초 무음 m4a(AAC)를 임시 폴더에 만들고 경로를 돌려준다.
    static func makeSilentM4A(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-silence-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)

        guard let pcmFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            throw AudioRecordingError.recordingFailed
        }
        let frameCount = AVAudioFrameCount(44_100 * seconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount) else {
            throw AudioRecordingError.recordingFailed
        }
        buffer.frameLength = frameCount  // 0으로 채워진 무음
        try file.write(from: buffer)
        return url
    }

    // MARK: - 샘플 ZIP (#10)

    /// 지정한 종류의 샘플 ZIP을 임시 폴더에 만들고 경로를 돌려준다.
    static func makeSampleZip(_ kind: DebugZipKind, now: Date = BlueHourClock.now()) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-zip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let zipURL = dir.appendingPathComponent(kind.fileName)

        let today = BlueHourCalendar.startOfLogicalDay(for: now, calendar: calendar)
        let far1 = calendar.date(byAdding: .day, value: -200, to: today) ?? today
        let far2 = calendar.date(byAdding: .day, value: -201, to: today) ?? today

        // 공통 정상 엔트리 2개(먼 과거라 보통 겹치지 않음)
        func normalEntries() -> [ExportEntry] {
            [exportEntry(date: far1, weather: .sunset),
             exportEntry(date: far2, weather: .fog)]
        }

        let archive = try Archive(url: zipURL, accessMode: .create)

        switch kind {
        case .normal:
            let doc = ExportDocument(formatVersion: 1, appVersion: "debug", exportedAt: now, entries: normalEntries())
            try addJSON(doc, to: archive)
            try addReadable(doc.entries, to: archive)

        case .overlap:
            // 오늘과 어제 날짜로 만들어 현재 기록과 겹치게 한다.
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let entries = [exportEntry(date: today, weather: .clearNight),
                           exportEntry(date: yesterday, weather: .cloudyNight)]
            let doc = ExportDocument(formatVersion: 1, appVersion: "debug", exportedAt: now, entries: entries)
            try addJSON(doc, to: archive)
            try addReadable(doc.entries, to: archive)

        case .badVersion:
            let doc = ExportDocument(formatVersion: 99, appVersion: "debug", exportedAt: now, entries: normalEntries())
            try addJSON(doc, to: archive)
            try addReadable(doc.entries, to: archive)

        case .corrupt:
            // 정상 JSON을 만든 뒤 뒤를 잘라 손상시킨다.
            let doc = ExportDocument(formatVersion: 1, appVersion: "debug", exportedAt: now, entries: normalEntries())
            let full = try DataTransfer.makeJSONEncoder().encode(doc)
            let truncated = full.prefix(full.count / 2)
            try addData(Data(truncated), name: DataTransfer.jsonFileName, to: archive)

        case .missingAudio:
            // JSON에는 음성 파일명이 있지만 recordings/에는 넣지 않는다.
            var entry = exportEntry(date: far1, weather: .shower)
            entry.audioFileName = "missing.m4a"
            entry.audioDuration = 5
            entry.audioCreatedAt = far1
            let doc = ExportDocument(formatVersion: 1, appVersion: "debug", exportedAt: now, entries: [entry])
            try addJSON(doc, to: archive)
            try addReadable(doc.entries, to: archive)
        }

        return zipURL
    }

    // MARK: - ZIP 보조

    private static func addJSON(_ doc: ExportDocument, to archive: Archive) throws {
        let data = try DataTransfer.makeJSONEncoder().encode(doc)
        try addData(data, name: DataTransfer.jsonFileName, to: archive)
    }

    private static func addReadable(_ entries: [ExportEntry], to archive: Archive) throws {
        let text = ReadableTextBuilder.build(entries: entries)
        try addData(Data(text.utf8), name: DataTransfer.readableTextFileName, to: archive)
    }

    private static func addData(_ data: Data, name: String, to archive: Archive) throws {
        try archive.addEntry(
            with: name,
            type: .file,
            uncompressedSize: Int64(data.count),
            provider: { position, size in
                let start = Int(position)
                return data.subdata(in: start ..< start + size)
            }
        )
    }

    private static func exportEntry(date: Date, weather: SkyWeatherType) -> ExportEntry {
        let c = sampleContent(for: weather)
        return ExportEntry(
            date: date,
            createdAt: date,
            updatedAt: date,
            originalText: c.original,
            editedText: nil,
            languageCode: "ko-KR",
            confidence: nil,
            analysis: ExportAnalysis(
                weatherType: weather.rawValue,
                title: c.title,
                summary: c.summary,
                emotionKeywords: c.keywords,
                mainTheme: c.theme,
                recoverySignal: c.recovery,
                tomorrowSentence: c.tomorrow,
                analyzedAt: date
            ),
            audioFileName: nil,
            audioDuration: nil,
            audioCreatedAt: nil
        )
    }

    // MARK: - 날씨별 샘플 문구

    private struct SampleContent {
        let title: String
        let summary: String
        let keywords: [String]
        let theme: String?
        let recovery: String?
        let tomorrow: String
        let original: String
    }

    private static func sampleContent(for weather: SkyWeatherType) -> SampleContent {
        let summary = "오늘은 \(weather.displayName) 같은 하루였어요. 마음이 한 방향으로만 흐르지 않고 여러 결을 지났어요. 그래도 끝에는 조금 잔잔해졌어요."
        return SampleContent(
            title: "\(weather.displayName)의 기록",
            summary: summary,
            keywords: ["차분함", "하루", weather.displayName],
            theme: "오늘 하루를 천천히 돌아봤어요.",
            recovery: "작은 순간에 숨을 돌렸어요.",
            tomorrow: "내일은 나에게 조금 더 너그러워도 괜찮아요.",
            original: "오늘은 \(weather.displayName) 같은 느낌이었어요. 이런저런 생각이 많았지만 그럭저럭 지나갔어요."
        )
    }
}
#endif
