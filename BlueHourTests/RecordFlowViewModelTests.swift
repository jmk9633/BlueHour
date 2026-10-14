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

    // MARK: - 8. 하루 1개 정책: 이미 기록이 있으면 새 녹음을 시작하지 않는다 (F-LKCUBW)

    func test_오늘기록이_있으면_새녹음을_시작하지않는다() async {
        let today = BlueHourCalendar.startOfLogicalToday()
        let existing = DiaryEntry(
            date: today,
            recording: nil,
            transcript: DiaryTranscript(originalText: "오늘 이미 기록함"),
            analysis: FakeSkyAnalysisService.defaultSky
        )
        let audio = FakeAudioRecordingService()
        let repository = FakeDiaryRepository(seed: [existing])
        let vm = makeViewModel(audio: audio, repository: repository, saveOriginalAudio: true)

        await vm.loadExistingEntry()
        XCTAssertNotNil(vm.existingEntry, "오늘 기록이 로드돼야 합니다.")

        await vm.startRecording()

        XCTAssertEqual(vm.state, .idle, "기록이 있으면 녹음을 시작하지 않고 그대로 있어야 합니다.")
        let didStart = await audio.didStartRecording
        XCTAssertFalse(didStart, "하루 1개 정책 위반: 기존 기록이 있는데 녹음이 시작됐습니다.")
    }

    // MARK: - 9. 최대 길이 도달 시 자동 정지 (F-AAPZHA)

    func test_최대길이_도달하면_자동정지된다() async {
        let audio = FakeAudioRecordingService(stopResult: ("rec.m4a", 0.5))
        let vm = RecordFlowViewModel(
            targetDate: BlueHourCalendar.startOfLogicalToday(),
            audioService: audio,
            speechService: FakeSpeechRecognitionService(),
            analysisService: FakeSkyAnalysisService(),
            repository: FakeDiaryRepository(),
            defaults: makeDefaults(saveOriginalAudio: true),
            maxDuration: 0.5   // 짧게 주입해 자동 정지를 빠르게 검증
        )

        await vm.startRecording()
        XCTAssertEqual(vm.state, .recording)

        // 0.5초 최대치를 넘기면 타이머가 자동으로 정지 → 변환 단계로 넘어간다.
        await waitUntil(timeout: 3.0) { vm.state != .recording }
        XCTAssertNotEqual(vm.state, .recording, "최대 길이에 도달하면 녹음이 멈춰야 합니다.")
        let didStop = await audio.didStartRecording
        XCTAssertTrue(didStop)
    }

    // MARK: - 10. 잠시 멈추면 타이머가 멈추고, 이어서 말하면 다시 흐른다 (S-KFMZEY)

    func test_일시중지중에는_타이머가_흐르지않는다() async {
        let audio = FakeAudioRecordingService()
        let vm = makeViewModel(audio: audio, saveOriginalAudio: true)

        await vm.startRecording()
        await vm.pauseRecording()
        XCTAssertTrue(vm.isPaused)

        let paused = vm.elapsedTime
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(vm.elapsedTime, paused, accuracy: 0.0001, "일시중지 중에는 시간이 흐르면 안 됩니다.")

        await vm.resumeRecording()
        XCTAssertFalse(vm.isPaused)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertGreaterThan(vm.elapsedTime, paused, "이어서 말하면 다시 시간이 흘러야 합니다.")

        await vm.restart()
    }

    // MARK: - 11. 음성 저장 설정은 소급 적용되지 않는다 (F-JJFVFE)

    func test_저장후_설정을_바꿔도_기존음성은_지워지지않는다() async {
        let audio = FakeAudioRecordingService(startFileName: "keep.m4a", stopResult: ("keep.m4a", 5.0))
        let repository = FakeDiaryRepository()
        let defaults = makeDefaults(saveOriginalAudio: true)   // 저장 시점엔 '목소리 남기기'
        let vm = RecordFlowViewModel(
            targetDate: BlueHourCalendar.startOfLogicalToday(),
            audioService: audio,
            speechService: FakeSpeechRecognitionService(),
            analysisService: FakeSkyAnalysisService(),
            repository: repository,
            defaults: defaults
        )

        await driveToReview(vm, text: "오늘 하루 잘 보냈어요.")
        await vm.confirmAndAnalyze()
        XCTAssertEqual(vm.state, .result)

        // 저장 뒤 '글과 하늘만 남기기'로 바꿔도 이미 저장된 기록의 음성은 지워지지 않는다.
        defaults.set(false, forKey: AppSettings.Keys.saveOriginalAudio)

        let deleted = await audio.wasDeleted("keep.m4a")
        XCTAssertFalse(deleted, "설정을 바꿨다고 이미 저장된 음성을 지우면 안 됩니다(소급 금지).")
        let saved = await repository.lastSaved
        XCTAssertEqual(saved?.recording?.fileName, "keep.m4a")
    }

    // MARK: - 12. AI 미지원 상태별 안내 이유 기록 (S-MEOLWE)

    func test_AI꺼짐이면_하늘없이저장하고_설정열기_이유를_기록한다() async {
        let audio = FakeAudioRecordingService()
        let analysis = FakeSkyAnalysisService(
            available: false,
            errorToThrow: SkyAnalysisError.modelUnavailable,
            reasonWhenUnavailable: .appleIntelligenceNotEnabled
        )
        let vm = makeViewModel(audio: audio, analysis: analysis, saveOriginalAudio: true)

        await driveToReview(vm, text: "오늘 하루 이야기예요.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .savedWithoutSky, "AI를 쓸 수 없으면 하늘 없이 저장돼야 합니다.")
        XCTAssertEqual(vm.undrawnReason, .appleIntelligenceNotEnabled)
    }

    func test_모델준비중이면_준비중_이유를_기록한다() async {
        let audio = FakeAudioRecordingService()
        let analysis = FakeSkyAnalysisService(
            available: false,
            errorToThrow: SkyAnalysisError.modelUnavailable,
            reasonWhenUnavailable: .modelNotReady
        )
        let vm = makeViewModel(audio: audio, analysis: analysis, saveOriginalAudio: true)

        await driveToReview(vm, text: "오늘 하루 이야기예요.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .savedWithoutSky)
        XCTAssertEqual(vm.undrawnReason, .modelNotReady)
    }

    // MARK: - 13. 아직 그려지지 않은 하늘 안내 문구 매핑 (S-MEOLWE / F-LLFPXL display)

    func test_그려지지않은하늘_안내문구는_이유별로_기획문구를_따른다() {
        XCTAssertEqual(
            UndrawnSkyResultView.guidance(for: .appleIntelligenceNotEnabled),
            "Apple Intelligence를 켜면 이 날의 하늘이 그려져요."
        )
        XCTAssertEqual(
            UndrawnSkyResultView.guidance(for: .modelNotReady),
            "하늘을 그릴 준비를 하고 있어요. 준비되면 자동으로 그려져요."
        )
        XCTAssertEqual(UndrawnSkyResultView.guidance(for: .deviceNotEligible), "하늘은 준비되면 곧 그려져요.")
        XCTAssertEqual(UndrawnSkyResultView.guidance(for: nil), "하늘은 준비되면 곧 그려져요.")
    }
}
