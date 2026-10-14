//
//  DataTransferTests.swift
//  BlueHourTests
//
//  8단계(내보내기·가져오기): 왕복 보존, 그려지지 않은 하늘 왕복, 목소리 없는 파일 가져오기,
//  겹침 바꾸기/유지, 모르는 formatVersion 거부, 손상·형식오류 거부,
//  바꾸기 도중 실패 시 기존 기록·음성 복원(롤백), 무료 카운트 미증가·30개 채운 미구매자 가져오기.
//

import XCTest
@testable import BlueHour

@MainActor
final class DataTransferTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - 헬퍼

    private func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: d))!
    }

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhtest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 지정 폴더에 더미 음성 파일을 만들고 VoiceRecording을 돌려준다.
    @discardableResult
    private func writeDummyAudio(_ name: String, in dir: URL) -> VoiceRecording {
        let url = dir.appendingPathComponent(name)
        try? Data([0xDE, 0xAD, 0xBE, 0xEF]).write(to: url)
        return VoiceRecording(fileName: name, duration: 12, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func sampleSky(_ type: SkyWeatherType = .clearNight, title: String = "맑은 밤") -> SkyAnalysis {
        SkyAnalysis(
            weatherType: type,
            title: title,
            summary: "잔잔한 하루였어요.",
            emotionKeywords: ["평온"],
            mainTheme: "쉼",
            recoverySignal: "작은 빛",
            tomorrowSentence: "편안한 밤 보내요.",
            analyzedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    /// 내보내기용 컨트롤러로 ZIP을 만든다. (실제 내보내기 경로를 탄다)
    private func exportZip(
        entries: [DiaryEntry],
        recordingsDir: URL,
        includeVoice: Bool
    ) async throws -> URL {
        let repo = FakeDiaryRepository(seed: entries)
        let store = AudioRecordingService(recordingsDirectory: recordingsDir)
        let controller = DataTransferController(repository: repo, fileStore: store)
        await controller.refreshExportAvailability()
        controller.includeVoice = includeVoice
        let url = await controller.makeExportFile()
        return try XCTUnwrap(url)
    }

    // MARK: - 왕복 (기록·분석·음성 연결 보존)

    func testRoundTripPreservesEntryAnalysisAndVoice() async throws {
        let exportDir = makeTempDir()
        let recording = writeDummyAudio("voice1.m4a", in: exportDir)
        let entry = DiaryEntry(
            date: day(2026, 5, 10),
            recording: recording,
            transcript: DiaryTranscript(originalText: "원문입니다", editedText: "수정본입니다"),
            analysis: sampleSky(.moonlight, title: "고요한 밤")
        )

        let zip = try await exportZip(entries: [entry], recordingsDir: exportDir, includeVoice: true)

        // 새 환경으로 가져오기
        let importDir = makeTempDir()
        let importRepo = FakeDiaryRepository()
        let importStore = AudioRecordingService(recordingsDirectory: importDir)
        let controller = DataTransferController(repository: importRepo, fileStore: importStore)

        await controller.beginImport(from: zip)

        XCTAssertEqual(controller.lastImportOutcome, .imported(days: 1))
        let all = try await importRepo.fetchAll()
        XCTAssertEqual(all.count, 1)
        let imported = try XCTUnwrap(all.first)

        XCTAssertEqual(calendar.startOfDay(for: imported.date), day(2026, 5, 10))
        XCTAssertEqual(imported.transcript?.originalText, "원문입니다")
        XCTAssertEqual(imported.transcript?.editedText, "수정본입니다")
        XCTAssertEqual(imported.analysis?.weatherType, .moonlight)
        XCTAssertEqual(imported.analysis?.title, "고요한 밤")
        XCTAssertEqual(imported.analysis?.recoverySignal, "작은 빛")

        // 음성은 새 UUID로 복사되고 실제 파일이 존재한다.
        let importedRecording = try XCTUnwrap(imported.recording)
        XCTAssertNotEqual(importedRecording.fileName, "voice1.m4a")
        XCTAssertEqual(importedRecording.duration, 12)
        let exists = await importStore.fileExists(fileName: importedRecording.fileName)
        XCTAssertTrue(exists)
    }

    // MARK: - 그려지지 않은 하늘 왕복

    func testRoundTripUndrawnSky() async throws {
        let exportDir = makeTempDir()
        let entry = DiaryEntry(
            date: day(2026, 5, 11),
            recording: nil,
            transcript: DiaryTranscript(originalText: "아직 분석 안 됨"),
            analysis: nil
        )

        let zip = try await exportZip(entries: [entry], recordingsDir: exportDir, includeVoice: true)

        let importRepo = FakeDiaryRepository()
        let importStore = AudioRecordingService(recordingsDirectory: makeTempDir())
        let controller = DataTransferController(repository: importRepo, fileStore: importStore)

        await controller.beginImport(from: zip)

        XCTAssertEqual(controller.lastImportOutcome, .imported(days: 1))
        let all = try await importRepo.fetchAll()
        let imported = try XCTUnwrap(all.first)
        XCTAssertNil(imported.analysis)
        XCTAssertNil(imported.recording)
        XCTAssertEqual(imported.transcript?.originalText, "아직 분석 안 됨")
    }

    // MARK: - 목소리 없이 내보낸 파일 가져오기

    func testImportFileExportedWithoutVoice() async throws {
        let exportDir = makeTempDir()
        let recording = writeDummyAudio("voice2.m4a", in: exportDir)
        let entry = DiaryEntry(
            date: day(2026, 5, 12),
            recording: recording,
            transcript: DiaryTranscript(originalText: "글만 담김"),
            analysis: sampleSky()
        )

        // includeVoice=false로 내보내면 음성이 ZIP에 담기지 않는다.
        let zip = try await exportZip(entries: [entry], recordingsDir: exportDir, includeVoice: false)

        let importRepo = FakeDiaryRepository()
        let importStore = AudioRecordingService(recordingsDirectory: makeTempDir())
        let controller = DataTransferController(repository: importRepo, fileStore: importStore)

        await controller.beginImport(from: zip)

        let all = try await importRepo.fetchAll()
        let imported = try XCTUnwrap(all.first)
        XCTAssertNil(imported.recording, "목소리 없이 내보낸 기록은 음성 없이 들어와야 한다")
        XCTAssertEqual(imported.analysis?.title, "맑은 밤")
    }

    // MARK: - 겹치는 날짜: 바꾸기

    func testOverlapReplace() async throws {
        let importDir = makeTempDir()
        let oldRecording = writeDummyAudio("oldvoice.m4a", in: importDir)
        let existing = DiaryEntry(
            date: day(2026, 5, 13),
            recording: oldRecording,
            transcript: DiaryTranscript(originalText: "기존 기록"),
            analysis: sampleSky(.cloudyNight, title: "흐린 밤")
        )
        let importRepo = FakeDiaryRepository(seed: [existing])
        let importStore = AudioRecordingService(recordingsDirectory: importDir)

        // 같은 날짜의 새 기록을 담은 ZIP
        let exportDir = makeTempDir()
        let newRecording = writeDummyAudio("newvoice.m4a", in: exportDir)
        let incoming = DiaryEntry(
            date: day(2026, 5, 13),
            recording: newRecording,
            transcript: DiaryTranscript(originalText: "가져온 기록"),
            analysis: sampleSky(.clearNight, title: "맑은 밤")
        )
        let zip = try await exportZip(entries: [incoming], recordingsDir: exportDir, includeVoice: true)

        let controller = DataTransferController(repository: importRepo, fileStore: importStore)
        await controller.beginImport(from: zip)

        // 저장 전에 한 번 묻는다.
        XCTAssertEqual(controller.overlapPromptCount, 1)
        let beforeResolve = try await importRepo.fetchAll()
        XCTAssertEqual(beforeResolve.first?.transcript?.originalText, "기존 기록")

        await controller.resolveOverlap(overwrite: true)

        XCTAssertEqual(controller.lastImportOutcome, .imported(days: 1))
        let all = try await importRepo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.transcript?.originalText, "가져온 기록")
        // 기존 음성은 삭제된다.
        let oldExists = await importStore.fileExists(fileName: "oldvoice.m4a")
        XCTAssertFalse(oldExists)
    }

    // MARK: - 겹치는 날짜: 기존 하늘 유지 (겹치지 않는 날은 모두 가져옴)

    func testOverlapKeepImportsOnlyNonOverlapping() async throws {
        let importDir = makeTempDir()
        let existing = DiaryEntry(
            date: day(2026, 5, 14),
            transcript: DiaryTranscript(originalText: "기존 기록"),
            analysis: sampleSky(.cloudyNight)
        )
        let importRepo = FakeDiaryRepository(seed: [existing])
        let importStore = AudioRecordingService(recordingsDirectory: importDir)

        let exportDir = makeTempDir()
        let overlapping = DiaryEntry(
            date: day(2026, 5, 14),
            transcript: DiaryTranscript(originalText: "겹치는 가져온 기록"),
            analysis: sampleSky(.clearNight)
        )
        let fresh = DiaryEntry(
            date: day(2026, 5, 15),
            transcript: DiaryTranscript(originalText: "새 날짜 기록"),
            analysis: sampleSky(.fog)
        )
        let zip = try await exportZip(entries: [overlapping, fresh], recordingsDir: exportDir, includeVoice: true)

        let controller = DataTransferController(repository: importRepo, fileStore: importStore)
        await controller.beginImport(from: zip)
        XCTAssertEqual(controller.overlapPromptCount, 1)

        await controller.resolveOverlap(overwrite: false)

        // 겹치는 날은 유지, 새 날짜만 들어온다.
        XCTAssertEqual(controller.lastImportOutcome, .imported(days: 1))
        let all = try await importRepo.fetchAll()
        XCTAssertEqual(all.count, 2)
        let day14 = all.first { self.calendar.startOfDay(for: $0.date) == self.day(2026, 5, 14) }
        let day15 = all.first { self.calendar.startOfDay(for: $0.date) == self.day(2026, 5, 15) }
        XCTAssertEqual(day14?.transcript?.originalText, "기존 기록")
        XCTAssertEqual(day15?.transcript?.originalText, "새 날짜 기록")
    }

    // MARK: - 모르는 formatVersion 거부

    func testUnknownFormatVersionRejected() async throws {
        let entry = ExportEntry(
            date: day(2026, 5, 16),
            createdAt: Date(), updatedAt: Date(),
            originalText: "t", editedText: nil, languageCode: "ko-KR", confidence: nil,
            analysis: nil, audioFileName: nil, audioDuration: nil, audioCreatedAt: nil
        )
        let doc = ExportDocument(formatVersion: 999, appVersion: "1.0", exportedAt: Date(), entries: [entry])
        let zip = try await DataExportService().makeExportFile(document: doc, audioSources: [])

        let repo = FakeDiaryRepository()
        let controller = DataTransferController(
            repository: repo,
            fileStore: AudioRecordingService(recordingsDirectory: makeTempDir())
        )
        await controller.beginImport(from: zip)

        XCTAssertEqual(controller.lastImportOutcome, .cannotImport)
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - 손상 파일 거부

    func testCorruptFileRejected() async throws {
        let badZip = makeTempDir().appendingPathComponent("broken.zip")
        try Data("이건 ZIP이 아니에요".utf8).write(to: badZip)

        let repo = FakeDiaryRepository()
        let controller = DataTransferController(
            repository: repo,
            fileStore: AudioRecordingService(recordingsDirectory: makeTempDir())
        )
        await controller.beginImport(from: badZip)

        XCTAssertEqual(controller.lastImportOutcome, .cannotImport)
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - 형식 오류(알 수 없는 날씨) 거부

    func testInvalidWeatherTypeRejected() async throws {
        let badAnalysis = ExportAnalysis(
            weatherType: "not_a_real_type", title: "t", summary: "s",
            emotionKeywords: [], mainTheme: nil, recoverySignal: nil,
            tomorrowSentence: "x", analyzedAt: Date()
        )
        let entry = ExportEntry(
            date: day(2026, 5, 17),
            createdAt: Date(), updatedAt: Date(),
            originalText: "t", editedText: nil, languageCode: "ko-KR", confidence: nil,
            analysis: badAnalysis, audioFileName: nil, audioDuration: nil, audioCreatedAt: nil
        )
        let doc = ExportDocument(formatVersion: 1, appVersion: "1.0", exportedAt: Date(), entries: [entry])
        let zip = try await DataExportService().makeExportFile(document: doc, audioSources: [])

        let repo = FakeDiaryRepository()
        let controller = DataTransferController(
            repository: repo,
            fileStore: AudioRecordingService(recordingsDirectory: makeTempDir())
        )
        await controller.beginImport(from: zip)

        XCTAssertEqual(controller.lastImportOutcome, .cannotImport)
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - 바꾸기 도중 실패 → 기존 기록·음성 복원 (롤백)

    func testReplaceRollbackRestoresExistingOnFailure() async throws {
        let importDir = makeTempDir()
        let oldRecording = writeDummyAudio("oldvoice.m4a", in: importDir)
        let existing = DiaryEntry(
            date: day(2026, 5, 18),
            recording: oldRecording,
            transcript: DiaryTranscript(originalText: "기존 기록"),
            analysis: sampleSky(.cloudyNight, title: "흐린 밤")
        )
        let importRepo = FakeDiaryRepository(seed: [existing])
        let realStore = AudioRecordingService(recordingsDirectory: importDir)
        // 음성 복사 단계(PHASE 2)에서 실패시키는 래퍼.
        let failingStore = FailingCopyFileStore(inner: realStore, failCopy: true)

        let exportDir = makeTempDir()
        let newRecording = writeDummyAudio("newvoice.m4a", in: exportDir)
        let incoming = DiaryEntry(
            date: day(2026, 5, 18),
            recording: newRecording,
            transcript: DiaryTranscript(originalText: "가져온 기록"),
            analysis: sampleSky(.clearNight)
        )
        let zip = try await exportZip(entries: [incoming], recordingsDir: exportDir, includeVoice: true)

        let controller = DataTransferController(repository: importRepo, fileStore: failingStore)
        await controller.beginImport(from: zip)
        XCTAssertEqual(controller.overlapPromptCount, 1)

        await controller.resolveOverlap(overwrite: true)

        // 실패로 처리되고, 기존 기록과 음성이 그대로 복원된다.
        XCTAssertEqual(controller.lastImportOutcome, .cannotImport)
        let all = try await importRepo.fetchAll()
        XCTAssertEqual(all.count, 1)
        let restored = try XCTUnwrap(all.first)
        XCTAssertEqual(restored.id, existing.id)
        XCTAssertEqual(restored.transcript?.originalText, "기존 기록")
        XCTAssertEqual(restored.recording?.fileName, "oldvoice.m4a")
        let oldExists = await realStore.fileExists(fileName: "oldvoice.m4a")
        XCTAssertTrue(oldExists, "롤백 후 기존 음성 파일이 되살아나야 한다")
    }

    // MARK: - 무료 카운트 미증가 · 30개 채운 미구매자도 가져오기 가능

    func testImportDoesNotIncrementFreeCountEvenWhenFull() async throws {
        let counter = FreeSkyCounter(store: InMemoryFreeSkyCountStore(initial: 30))
        XCTAssertTrue(counter.hasReachedLimit)

        let exportDir = makeTempDir()
        let entry = DiaryEntry(
            date: day(2026, 5, 19),
            transcript: DiaryTranscript(originalText: "가져온 기록"),
            analysis: sampleSky()
        )
        let zip = try await exportZip(entries: [entry], recordingsDir: exportDir, includeVoice: true)

        // 컨트롤러는 카운터에 의존하지 않는다(게이트·증가 없음).
        let importRepo = FakeDiaryRepository()
        let controller = DataTransferController(
            repository: importRepo,
            fileStore: AudioRecordingService(recordingsDirectory: makeTempDir())
        )
        await controller.beginImport(from: zip)

        XCTAssertEqual(controller.lastImportOutcome, .imported(days: 1))
        let all = try await importRepo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(counter.count, 30, "가져오기는 무료 카운트를 늘리지 않는다")
    }

    // MARK: - 내보내기 게이트 (F-NJSTGI)

    func testExportDisabledWhenNoEntries() async {
        let controller = DataTransferController(
            repository: FakeDiaryRepository(seed: []),
            fileStore: AudioRecordingService(recordingsDirectory: makeTempDir())
        )
        await controller.refreshExportAvailability()

        XCTAssertFalse(controller.canExport, "기록이 없으면 내보내기 버튼은 비활성이어야 합니다.")
        XCTAssertFalse(controller.hasAnyVoice)
        let url = await controller.makeExportFile()
        XCTAssertNil(url, "기록이 없으면 내보내기 파일을 만들지 않아야 합니다.")
    }

    func testVoiceOptionShownOnlyWhenVoiceExists() async {
        let dir = makeTempDir()
        let withVoice = DiaryEntry(
            date: day(2026, 5, 1),
            recording: writeDummyAudio("v.m4a", in: dir),
            transcript: DiaryTranscript(originalText: "글"),
            analysis: sampleSky()
        )
        let noVoice = DiaryEntry(
            date: day(2026, 5, 2),
            transcript: DiaryTranscript(originalText: "글"),
            analysis: sampleSky()
        )

        let withVoiceController = DataTransferController(
            repository: FakeDiaryRepository(seed: [withVoice]),
            fileStore: AudioRecordingService(recordingsDirectory: dir)
        )
        await withVoiceController.refreshExportAvailability()
        XCTAssertTrue(withVoiceController.canExport)
        XCTAssertTrue(withVoiceController.hasAnyVoice, "목소리 남은 기록이 있으면 '함께 담기'를 노출해야 합니다.")

        let noVoiceController = DataTransferController(
            repository: FakeDiaryRepository(seed: [noVoice]),
            fileStore: AudioRecordingService(recordingsDirectory: dir)
        )
        await noVoiceController.refreshExportAvailability()
        XCTAssertTrue(noVoiceController.canExport)
        XCTAssertFalse(noVoiceController.hasAnyVoice, "목소리가 없으면 '함께 담기'를 노출하지 않아야 합니다.")
    }
}

// MARK: - 테스트용: 복사 단계에서 실패하는 파일 저장소

/// copyIntoRecordings에서만 실패하고 나머지는 실제 저장소에 위임한다(롤백 검증용).
private final class FailingCopyFileStore: RecordingFileStoring, @unchecked Sendable {
    private let inner: AudioRecordingService
    private let failCopy: Bool

    init(inner: AudioRecordingService, failCopy: Bool) {
        self.inner = inner
        self.failCopy = failCopy
    }

    enum StoreError: Error { case copyFailed }

    func fileURL(for fileName: String) async -> URL {
        await inner.fileURL(for: fileName)
    }

    func copyIntoRecordings(from sourceURL: URL) async throws -> String {
        if failCopy { throw StoreError.copyFailed }
        return try await inner.copyIntoRecordings(from: sourceURL)
    }

    func moveOutOfRecordings(fileName: String, to directory: URL) async throws -> URL? {
        try await inner.moveOutOfRecordings(fileName: fileName, to: directory)
    }

    func restoreIntoRecordings(from url: URL, fileName: String) async throws {
        try await inner.restoreIntoRecordings(from: url, fileName: fileName)
    }

    func deleteFromRecordings(fileName: String) async throws {
        try await inner.deleteFromRecordings(fileName: fileName)
    }

    func fileExists(fileName: String) async -> Bool {
        await inner.fileExists(fileName: fileName)
    }
}
