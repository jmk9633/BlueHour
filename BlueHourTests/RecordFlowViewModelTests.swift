//
//  RecordFlowViewModelTests.swift
//  BlueHourTests
//
//  2단계(녹음/저장 견고화) 로직 검증.
//

import XCTest
import AVFoundation
@testable import BlueHour

@MainActor
final class RecordFlowViewModelTests: XCTestCase {

    // MARK: - 헬퍼

    private func makeDefaults(saveOriginalAudio: Bool) -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(saveOriginalAudio, forKey: AppSettings.Keys.saveOriginalAudio)
        return defaults
    }

    private func makeViewModel(
        audio: FakeAudioRecordingService,
        speech: FakeSpeechRecognitionService = FakeSpeechRecognitionService(),
        analysis: FakeSkyAnalysisService = FakeSkyAnalysisService(),
        repository: FakeDiaryRepository = FakeDiaryRepository(),
        saveOriginalAudio: Bool
    ) -> RecordFlowViewModel {
        RecordFlowViewModel(
            targetDate: BlueHourCalendar.startOfLogicalToday(),
            audioService: audio,
            speechService: speech,
            analysisService: analysis,
            repository: repository,
            defaults: makeDefaults(saveOriginalAudio: saveOriginalAudio)
        )
    }

    /// 녹음 → 인터럽션 보존 → 변환 → 리뷰까지 몰고 간다. (보존 길이 5초 = 저장 가능)
    private func driveToReview(_ vm: RecordFlowViewModel, text: String) async {
        await vm.startRecording()
        await vm.handleInterruption()
        await vm.continueAfterInterruption()
        vm.editableText = text
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        _ condition: @MainActor () -> Bool
    ) async {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("조건이 \(timeout)초 내에 충족되지 않았습니다.")
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - 1. 3초 미만 녹음은 저장되지 않는다

    func test_recordingUnderThreeSeconds_isNotSaved() async {
        let audio = FakeAudioRecordingService()
        let repository = FakeDiaryRepository()
        let vm = makeViewModel(audio: audio, repository: repository, saveOriginalAudio: true)

        await vm.startRecording()
        XCTAssertEqual(vm.state, .recording)

        // 아직 3초가 지나지 않은 시점(약 0.3초)에 저장 요청
        try? await Task.sleep(for: .milliseconds(300))
        let saved = await vm.requestSave()

        XCTAssertFalse(saved, "3초 미만인데 저장이 진행됐습니다.")
        XCTAssertEqual(vm.state, .recording, "저장 실패 시에도 녹음은 계속 유지돼야 합니다.")
        let count = await repository.saved.count
        XCTAssertEqual(count, 0, "3초 미만 녹음이 저장됐습니다.")

        await vm.restart()   // 타이머 정리
    }

    // MARK: - 2. saveOriginalAudio=false → 음성 파일 삭제 + recording nil

    func test_saveOriginalAudioFalse_deletesAudioAndRecordingIsNil() async {
        let audio = FakeAudioRecordingService(startFileName: "rec.m4a",
                                              stopResult: ("rec.m4a", 5.0))
        let repository = FakeDiaryRepository()
        let vm = makeViewModel(audio: audio, repository: repository, saveOriginalAudio: false)

        await driveToReview(vm, text: "오늘 하루 잘 보냈어요.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)
        let deleted = await audio.wasDeleted("rec.m4a")
        XCTAssertTrue(deleted, "saveOriginalAudio=false인데 음성 파일이 삭제되지 않았습니다.")
        let saved = await repository.lastSaved
        XCTAssertNotNil(saved)
        XCTAssertNil(saved?.recording, "saveOriginalAudio=false인데 recording이 남아 있습니다.")
    }

    // MARK: - 3. saveOriginalAudio=true → 음성 파일 유지

    func test_saveOriginalAudioTrue_keepsAudioFile() async {
        let audio = FakeAudioRecordingService(startFileName: "rec.m4a",
                                              stopResult: ("rec.m4a", 5.0))
        let repository = FakeDiaryRepository()
        let vm = makeViewModel(audio: audio, repository: repository, saveOriginalAudio: true)

        await driveToReview(vm, text: "오늘 하루 잘 보냈어요.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)
        let deleted = await audio.wasDeleted("rec.m4a")
        XCTAssertFalse(deleted, "saveOriginalAudio=true인데 음성 파일이 삭제됐습니다.")
        let saved = await repository.lastSaved
        XCTAssertEqual(saved?.recording?.fileName, "rec.m4a")
    }

    // MARK: - 4. 편집 모드에서는 기존 음성 파일을 삭제하지 않는다

    func test_editMode_doesNotDeleteExistingAudio() async {
        let audio = FakeAudioRecordingService()
        let existing = DiaryEntry(
            date: BlueHourCalendar.startOfLogicalToday(),
            recording: VoiceRecording(fileName: "old.m4a", duration: 10),
            transcript: DiaryTranscript(originalText: "원본 내용"),
            analysis: FakeSkyAnalysisService.defaultSky
        )
        let repository = FakeDiaryRepository(seed: [existing])
        // saveOriginalAudio=false로 두어도 편집 모드에서는 삭제되면 안 된다
        let vm = makeViewModel(audio: audio, repository: repository, saveOriginalAudio: false)

        vm.startTextEdit(entry: existing)
        vm.editableText = "수정된 내용"
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)
        let deleted = await audio.wasDeleted("old.m4a")
        XCTAssertFalse(deleted, "편집 모드에서 기존 음성 파일이 삭제됐습니다.")
        let updated = await repository.lastUpdated
        XCTAssertEqual(updated?.recording?.fileName, "old.m4a", "편집 후 기존 음성 연결이 사라졌습니다.")
    }

    // MARK: - 6. 인터럽션 신호 → 녹음 정지 + state .interrupted

    func test_interruptionSignal_stopsAndSetsInterrupted() async {
        let audio = FakeAudioRecordingService(stopResult: ("rec.m4a", 5.0))
        let vm = makeViewModel(audio: audio, saveOriginalAudio: true)

        await vm.startRecording()
        XCTAssertEqual(vm.state, .recording)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        await waitUntil { vm.state == .interrupted }
        XCTAssertEqual(vm.state, .interrupted)
        XCTAssertTrue(vm.canSavePreservedRecording, "5초 보존본은 저장 가능해야 합니다.")
    }

    // MARK: - 7. 인터럽션 후 3초 미만 → canSavePreservedRecording == false

    func test_interruptionShortRecording_cannotSave() async {
        let audio = FakeAudioRecordingService(stopResult: ("rec.m4a", 2.0))
        let vm = makeViewModel(audio: audio, saveOriginalAudio: true)

        await vm.startRecording()
        await vm.handleInterruption()

        XCTAssertEqual(vm.state, .interrupted)
        XCTAssertFalse(vm.canSavePreservedRecording, "2초 보존본인데 저장 가능으로 판정됐습니다.")
    }
}
