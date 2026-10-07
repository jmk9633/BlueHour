//
//  Fakes.swift
//  BlueHourTests
//
//  유닛 테스트용 가짜 서비스/리포지토리. 실제 AVFoundation·Speech·FoundationModels·SwiftData에
//  의존하지 않고 RecordFlowViewModel의 로직만 결정적으로 검증하기 위한 대역이다.
//

import Foundation
@testable import BlueHour

// MARK: - 오디오 녹음

actor FakeAudioRecordingService: AudioRecordingServiceProtocol {
    var permissionGranted: Bool
    var startFileName: String
    var stopResult: (fileName: String, duration: TimeInterval)

    private(set) var deletedFileNames: [String] = []
    private(set) var deleteAllCalled = false
    private(set) var didStartRecording = false
    private(set) var didCancel = false

    init(
        permissionGranted: Bool = true,
        startFileName: String = "rec.m4a",
        stopResult: (fileName: String, duration: TimeInterval) = ("rec.m4a", 5.0)
    ) {
        self.permissionGranted = permissionGranted
        self.startFileName = startFileName
        self.stopResult = stopResult
    }

    func requestPermission() async -> Bool { permissionGranted }

    func startRecording() async throws -> String {
        didStartRecording = true
        return startFileName
    }

    func pauseRecording() async {}
    func resumeRecording() async throws {}

    func stopRecording() async throws -> (fileName: String, duration: TimeInterval) {
        stopResult
    }

    func cancelRecording() async { didCancel = true }

    func deleteRecording(fileName: String) async throws {
        deletedFileNames.append(fileName)
    }

    func deleteAllRecordings() async throws { deleteAllCalled = true }

    // 조회 헬퍼
    func wasDeleted(_ fileName: String) -> Bool { deletedFileNames.contains(fileName) }
}

// MARK: - 음성 인식

actor FakeSpeechRecognitionService: SpeechRecognitionServiceProtocol {
    var transcriptText: String

    init(transcriptText: String = "오늘은 잔잔한 하루였어요.") {
        self.transcriptText = transcriptText
    }

    func requestPermission() async -> Bool { true }

    func transcribe(fileName: String, languageCode: String) async throws -> DiaryTranscript {
        DiaryTranscript(originalText: transcriptText, languageCode: languageCode)
    }
}

// MARK: - 하늘 분석

actor FakeSkyAnalysisService: SkyAnalysisServiceProtocol {
    var result: SkyAnalysis

    init(result: SkyAnalysis = FakeSkyAnalysisService.defaultSky) {
        self.result = result
    }

    func analyze(text: String) async throws -> SkyAnalysis { result }

    static let defaultSky = SkyAnalysis(
        weatherType: .moonlight,
        title: "고요한 밤",
        summary: "잔잔하게 흘러간 하루였어요.",
        emotionKeywords: ["평온"],
        tomorrowSentence: "편안한 밤 보내요."
    )
}

// MARK: - 일기 저장소 (인메모리)

actor FakeDiaryRepository: DiaryRepositoryProtocol {
    private(set) var saved: [DiaryEntry] = []
    private(set) var updated: [DiaryEntry] = []
    private(set) var deletedIDs: [UUID] = []

    init(seed: [DiaryEntry] = []) {
        self.saved = seed
    }

    func save(_ entry: DiaryEntry) async throws { saved.append(entry) }

    func update(_ entry: DiaryEntry) async throws {
        updated.append(entry)
        if let index = saved.firstIndex(where: { $0.id == entry.id }) {
            saved[index] = entry
        }
    }

    func delete(id: UUID) async throws {
        deletedIDs.append(id)
        saved.removeAll { $0.id == id }
    }

    func deleteAll() async throws { saved.removeAll() }

    func fetch(id: UUID) async throws -> DiaryEntry? {
        saved.first { $0.id == id }
    }

    func fetchEntry(on date: Date) async throws -> DiaryEntry? {
        let calendar = Calendar.current
        return saved.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchEntries(in interval: DateInterval) async throws -> [DiaryEntry] {
        saved.filter { interval.contains($0.date) }
    }

    func fetchAll() async throws -> [DiaryEntry] { saved }

    // 조회 헬퍼
    var lastSaved: DiaryEntry? { saved.last }
    var lastUpdated: DiaryEntry? { updated.last }
}
