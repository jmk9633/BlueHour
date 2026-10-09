//
//  RecordManagementTests.swift
//  BlueHourTests
//
//  4단계(기록 관리): 다시 말하기 교체/취소, 목소리 지우기, 수정 후 재분석 실패.
//

import XCTest
@testable import BlueHour

@MainActor
final class RecordManagementTests: XCTestCase {

    private let day = Calendar.current.startOfDay(for: Date())

    private func makeDefaults(saveOriginalAudio: Bool = true) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        defaults.set(saveOriginalAudio, forKey: AppSettings.Keys.saveOriginalAudio)
        return defaults
    }

    private func oldSky(title: String = "이전 하늘") -> SkyAnalysis {
        SkyAnalysis(
            weatherType: .moonlight,
            title: title,
            summary: "이전 요약이에요.",
            emotionKeywords: ["평온"],
            tomorrowSentence: "편안한 밤 보내요."
        )
    }

    private func newSky(title: String = "새로 그린 하늘") -> SkyAnalysis {
        SkyAnalysis(
            weatherType: .sunset,
            title: title,
            summary: "새 요약이에요.",
            emotionKeywords: ["설렘"],
            tomorrowSentence: "내일도 천천히 만나요."
        )
    }

    private func seededEntry(recordingName: String? = "old.m4a", analysis: SkyAnalysis?) -> DiaryEntry {
        DiaryEntry(
            date: day,
            recording: recordingName.map { VoiceRecording(fileName: $0, duration: 10) },
            transcript: DiaryTranscript(originalText: "이전 글"),
            analysis: analysis
        )
    }

    private func makeReplaceViewModel(
        repository: FakeDiaryRepository,
        audio: FakeAudioRecordingService,
        analysis: FakeSkyAnalysisService
    ) -> RecordFlowViewModel {
        RecordFlowViewModel(
            targetDate: day,
            replaceExisting: true,
            audioService: audio,
            speechService: FakeSpeechRecognitionService(),
            analysisService: analysis,
            repository: repository,
            defaults: makeDefaults()
        )
    }

    // MARK: - 1. 다시 말하기 저장 → 기존 기록 교체 + 이전 음성 삭제

    func test_respeak_replacesEntryAndDeletesOldAudio() async {
        let old = seededEntry(recordingName: "old.m4a", analysis: oldSky())
        let repository = FakeDiaryRepository(seed: [old])
        let audio = FakeAudioRecordingService(startFileName: "new.m4a", stopResult: ("new.m4a", 5.0))
        let analysis = FakeSkyAnalysisService(result: newSky())
        let vm = makeReplaceViewModel(repository: repository, audio: audio, analysis: analysis)

        await vm.startRecording()
        await vm.handleInterruption()
        await vm.continueAfterInterruption()
        vm.editableText = "새로 말한 내용"
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)

        let saved = await repository.saved
        XCTAssertEqual(saved.count, 1, "기존 기록은 지워지고 새 기록 하나만 남아야 함")
        XCTAssertEqual(saved.first?.analysis?.title, "새로 그린 하늘")
        XCTAssertEqual(saved.first?.recording?.fileName, "new.m4a")

        let deletedOld = await audio.wasDeleted("old.m4a")
        XCTAssertTrue(deletedOld, "이전 음성 파일이 삭제돼야 함")
        let deletedIDs = await repository.deletedIDs
        XCTAssertTrue(deletedIDs.contains(old.id))
    }

    // MARK: - 2. 다시 말하기 도중 취소 → 기존 기록 그대로

    func test_respeak_cancelDuringRecording_keepsOldEntry() async {
        let old = seededEntry(recordingName: "old.m4a", analysis: oldSky())
        let repository = FakeDiaryRepository(seed: [old])
        let audio = FakeAudioRecordingService(startFileName: "new.m4a", stopResult: ("new.m4a", 5.0))
        let analysis = FakeSkyAnalysisService(result: newSky())
        let vm = makeReplaceViewModel(repository: repository, audio: audio, analysis: analysis)

        await vm.startRecording()
        await vm.restart()   // 녹음 중 취소

        let saved = await repository.saved
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.id, old.id, "기존 기록이 그대로 남아야 함")
        let deletedOld = await audio.wasDeleted("old.m4a")
        XCTAssertFalse(deletedOld, "취소 시 이전 음성은 지워지면 안 됨")
    }

    // MARK: - (추가) 저장 전까지는 교체가 일어나지 않는다 — 텍스트 확인 단계에서 이탈

    func test_respeak_exitAtReview_doesNotReplace() async {
        let old = seededEntry(recordingName: "old.m4a", analysis: oldSky())
        let repository = FakeDiaryRepository(seed: [old])
        let audio = FakeAudioRecordingService(startFileName: "new.m4a", stopResult: ("new.m4a", 5.0))
        let analysis = FakeSkyAnalysisService(result: newSky())
        let vm = makeReplaceViewModel(repository: repository, audio: audio, analysis: analysis)

        await vm.startRecording()
        await vm.handleInterruption()
        await vm.continueAfterInterruption()  // 텍스트 확인(reviewing) 단계
        await vm.restart()                    // 저장하지 않고 이탈

        let saved = await repository.saved
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.id, old.id, "저장 전에는 기존 기록이 유지돼야 함")
        let deletedOld = await audio.wasDeleted("old.m4a")
        XCTAssertFalse(deletedOld, "저장 전에는 이전 음성이 지워지면 안 됨")
    }

    // MARK: - 3. 목소리 지우기 → recording nil, analysis·transcript 유지

    func test_eraseVoice_removesOnlyRecording() async {
        let entry = seededEntry(recordingName: "v.m4a", analysis: oldSky(title: "남아야 하는 하늘"))
        let repository = FakeDiaryRepository(seed: [entry])
        let audio = FakeAudioRecordingService()
        let vm = SkyDetailViewModel(entry: entry, repository: repository, audioService: audio)

        await vm.eraseVoice()

        let deleted = await audio.wasDeleted("v.m4a")
        XCTAssertTrue(deleted, "음성 파일이 삭제돼야 함")
        XCTAssertNil(vm.entry.recording, "recording은 nil")
        XCTAssertEqual(vm.entry.analysis?.title, "남아야 하는 하늘", "하늘은 유지")
        XCTAssertEqual(vm.entry.transcript?.displayText, "이전 글", "글은 유지")

        let updated = await repository.lastUpdated
        XCTAssertNil(updated?.recording)
        XCTAssertNotNil(updated?.analysis)
    }

    // MARK: - 4. 수정 후 재분석 실패 → 수정 텍스트 저장 + 이전 하늘 유지

    func test_editReanalyzeFails_savesTextKeepsOldAnalysis() async {
        let entry = DiaryEntry(
            date: day,
            recording: nil,
            transcript: DiaryTranscript(originalText: "원래 글"),
            analysis: oldSky(title: "이전 하늘")
        )
        let repository = FakeDiaryRepository(seed: [entry])
        let audio = FakeAudioRecordingService()
        let analysis = FakeSkyAnalysisService(errorToThrow: SkyAnalysisError.analysisFailed)
        let vm = RecordFlowViewModel(
            targetDate: day,
            audioService: audio,
            speechService: FakeSpeechRecognitionService(),
            analysisService: analysis,
            repository: repository,
            defaults: makeDefaults()
        )

        vm.startTextEdit(entry: entry)
        vm.editableText = "고친 글"
        await vm.confirmAndAnalyze()

        let updated = await repository.lastUpdated
        XCTAssertEqual(updated?.transcript?.displayText, "고친 글", "수정한 텍스트는 저장돼야 함")
        XCTAssertEqual(updated?.analysis?.title, "이전 하늘", "이전 하늘(analysis)은 유지돼야 함")
        XCTAssertEqual(vm.state, .result)
    }
}
