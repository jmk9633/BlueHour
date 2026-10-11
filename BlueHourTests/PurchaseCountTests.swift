//
//  PurchaseCountTests.swift
//  BlueHourTests
//
//  6단계(구매 · 무료 30개 카운트): 카운트 증가/미증가, 입구 차단, 구매 후 해제,
//  삭제·재설치해도 유지, 30번째 안내 1회, 구매 복원 문구.
//

import XCTest
@testable import BlueHour

@MainActor
final class PurchaseCountTests: XCTestCase {

    private let day = BlueHourCalendar.startOfLogicalToday()

    // MARK: - 헬퍼

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        defaults.set(true, forKey: AppSettings.Keys.saveOriginalAudio)
        defaults.set(false, forKey: AppSettings.Keys.hasShownFreeLimitNotice)
        return defaults
    }

    private func makeCounter(initial: Int = 0, limit: Int = 30) -> FreeSkyCounter {
        FreeSkyCounter(store: InMemoryFreeSkyCountStore(initial: initial), limit: limit)
    }

    private func makeVM(
        entitlement: FakeEntitlement,
        counter: FreeSkyCounter,
        repository: FakeDiaryRepository = FakeDiaryRepository(),
        audio: FakeAudioRecordingService = FakeAudioRecordingService(),
        analysis: FakeSkyAnalysisService = FakeSkyAnalysisService(),
        replaceExisting: Bool = false,
        defaults: UserDefaults
    ) -> RecordFlowViewModel {
        RecordFlowViewModel(
            targetDate: day,
            replaceExisting: replaceExisting,
            audioService: audio,
            speechService: FakeSpeechRecognitionService(),
            analysisService: analysis,
            repository: repository,
            defaults: defaults,
            entitlement: entitlement,
            freeSkyCounter: counter
        )
    }

    /// 녹음 → 인터럽션 보존 → 변환 → 리뷰까지 몰고 간다(보존 5초 = 저장 가능).
    private func driveToReview(_ vm: RecordFlowViewModel, text: String) async {
        await vm.startRecording()
        await vm.handleInterruption()
        await vm.continueAfterInterruption()
        vm.editableText = text
    }

    // MARK: - 카운트 증가

    func test_newRecording_incrementsCount() async {
        let counter = makeCounter(initial: 0)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, defaults: makeDefaults())

        await driveToReview(vm, text: "오늘은 잔잔했어요.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)
        XCTAssertEqual(counter.count, 1, "새 기록 저장 시 카운트가 1 늘어야 합니다.")
    }

    func test_textWriting_incrementsCount() async {
        let counter = makeCounter(initial: 0)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, defaults: makeDefaults())

        await vm.beginTextWriting()
        XCTAssertEqual(vm.state, .reviewing, "한도 미달이면 텍스트 입구가 열려야 합니다.")
        vm.editableText = "글로 남긴 오늘."
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)
        XCTAssertEqual(counter.count, 1, "텍스트로 쓰기도 새 기록이므로 +1이어야 합니다.")
    }

    func test_savedWithoutSky_incrementsCount() async {
        let counter = makeCounter(initial: 0)
        let analysis = FakeSkyAnalysisService(errorToThrow: SkyAnalysisError.modelUnavailable)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, analysis: analysis, defaults: makeDefaults())

        await driveToReview(vm, text: "AI 없이 저장되는 날.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .savedWithoutSky)
        XCTAssertEqual(counter.count, 1, "하늘 없이 저장해도 카운트는 +1이어야 합니다.")
    }

    // MARK: - 카운트 미증가

    func test_respeak_doesNotIncrement() async {
        let old = DiaryEntry(
            date: day,
            recording: VoiceRecording(fileName: "old.m4a", duration: 10),
            transcript: DiaryTranscript(originalText: "이전 글"),
            analysis: FakeSkyAnalysisService.defaultSky
        )
        let repository = FakeDiaryRepository(seed: [old])
        let counter = makeCounter(initial: 5)
        let audio = FakeAudioRecordingService(startFileName: "new.m4a", stopResult: ("new.m4a", 5.0))
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, repository: repository, audio: audio,
                        replaceExisting: true, defaults: makeDefaults())

        await driveToReview(vm, text: "다시 말한 내용.")
        await vm.confirmAndAnalyze()

        XCTAssertEqual(vm.state, .result)
        XCTAssertEqual(counter.count, 5, "다시 말하기(교체)는 카운트를 늘리면 안 됩니다.")
    }

    func test_edit_doesNotIncrement() async {
        let entry = DiaryEntry(
            date: day,
            recording: nil,
            transcript: DiaryTranscript(originalText: "원래 글"),
            analysis: FakeSkyAnalysisService.defaultSky
        )
        let repository = FakeDiaryRepository(seed: [entry])
        let counter = makeCounter(initial: 5)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, repository: repository, defaults: makeDefaults())

        vm.startTextEdit(entry: entry)
        vm.editableText = "고친 글"
        await vm.confirmAndAnalyze()

        XCTAssertEqual(counter.count, 5, "수정은 카운트를 늘리면 안 됩니다.")
    }

    func test_analysisFailure_doesNotIncrement() async {
        let counter = makeCounter(initial: 0)
        let analysis = FakeSkyAnalysisService(errorToThrow: SkyAnalysisError.analysisFailed)
        let repository = FakeDiaryRepository()
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, repository: repository, analysis: analysis,
                        defaults: makeDefaults())

        await driveToReview(vm, text: "분석이 실패하는 날.")
        await vm.confirmAndAnalyze()

        if case .failed = vm.state {} else { XCTFail("분석 실패 상태여야 합니다.") }
        XCTAssertEqual(counter.count, 0, "분석·저장 실패 시 카운트는 늘지 않아야 합니다.")
        let saved = await repository.saved.count
        XCTAssertEqual(saved, 0)
    }

    func test_cancel_doesNotIncrement() async {
        let counter = makeCounter(initial: 0)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, defaults: makeDefaults())

        await vm.startRecording()
        await vm.restart()   // 녹음 취소

        XCTAssertEqual(counter.count, 0, "녹음 취소 시 카운트는 늘지 않아야 합니다.")
    }

    // MARK: - 30 도달 시 입구 차단

    func test_atLimit_blocksRecordingEntry() async {
        let counter = makeCounter(initial: 30)
        let repository = FakeDiaryRepository()
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, repository: repository, defaults: makeDefaults())

        await vm.beginRecording()

        XCTAssertTrue(vm.showPurchase, "한도 도달 시 구매 화면을 열어야 합니다.")
        XCTAssertEqual(vm.state, .idle, "녹음을 시작하면 안 됩니다.")
        let saved = await repository.saved.count
        XCTAssertEqual(saved, 0)
        XCTAssertEqual(counter.count, 30, "차단만 하고 카운트는 그대로여야 합니다.")
    }

    func test_atLimit_blocksTextWritingEntry() async {
        let counter = makeCounter(initial: 30)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                        counter: counter, defaults: makeDefaults())

        await vm.beginTextWriting()

        XCTAssertTrue(vm.showPurchase, "한도 도달 시 구매 화면을 열어야 합니다.")
        XCTAssertEqual(vm.state, .idle, "리뷰 화면으로 넘어가면 안 됩니다.")
    }

    func test_atLimit_blocksCalendarEntry() async {
        let blocked = SkyCalendarViewModel(
            repository: FakeDiaryRepository(),
            entitlement: FakeEntitlement(isUnlocked: false),
            counter: makeCounter(initial: 30)
        )
        let open = SkyCalendarViewModel(
            repository: FakeDiaryRepository(),
            entitlement: FakeEntitlement(isUnlocked: false),
            counter: makeCounter(initial: 29)
        )

        let blockedResult = await blocked.canStartNewEntry()
        let openResult = await open.canStartNewEntry()

        XCTAssertFalse(blockedResult, "30개면 빈 과거 날짜 입구가 막혀야 합니다.")
        XCTAssertTrue(openResult, "29개면 빈 과거 날짜 입구가 열려야 합니다.")
    }

    // MARK: - 구매 후 해제

    func test_purchasedUser_passesAtLimit() async {
        let counter = makeCounter(initial: 30)
        let vm = makeVM(entitlement: FakeEntitlement(isUnlocked: true),
                        counter: counter, defaults: makeDefaults())

        await vm.beginRecording()

        XCTAssertFalse(vm.showPurchase, "구매자는 한도와 무관하게 통과해야 합니다.")
        XCTAssertEqual(vm.state, .recording)
    }

    // MARK: - 구매 여부 확인 전 대기 → 구매자는 통과

    func test_waitsForReadiness_thenPurchaserPasses() async {
        let entitlement = FakeEntitlement(isUnlocked: false, ready: false)
        let counter = makeCounter(initial: 30)

        let gate = Task {
            await NewEntryGate.canStartNewEntry(entitlement: entitlement, counter: counter)
        }
        // 아직 확인 전. 구매자로 확인이 끝나면 통과해야 한다.
        entitlement.markReady(unlocked: true)
        let result = await gate.value

        XCTAssertTrue(result, "확인이 끝날 때까지 기다린 뒤 구매자로 판정돼 통과해야 합니다.")
    }

    // MARK: - 삭제·재설치해도 유지

    func test_countPersistsAcrossReinstall() {
        let store = InMemoryFreeSkyCountStore(initial: 0)
        let first = FreeSkyCounter(store: store, limit: 30)
        first.increment()
        first.increment()
        XCTAssertEqual(first.count, 2)

        // 재설치/전체삭제 흉내: 같은 키체인(저장소)에서 새 카운터를 만든다.
        let second = FreeSkyCounter(store: store, limit: 30)
        XCTAssertEqual(second.count, 2, "재설치·전체삭제에도 카운트는 유지돼야 합니다.")
    }

    // MARK: - 30번째 결과 카드 안내 1회

    func test_thirtiethSky_showsNoticeOnce() async {
        let defaults = makeDefaults()

        // 29 → 30: 이때 한 번 안내.
        let counterA = makeCounter(initial: 29)
        let vmA = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                         counter: counterA, defaults: defaults)
        await driveToReview(vmA, text: "서른 번째 하늘.")
        await vmA.confirmAndAnalyze()
        XCTAssertEqual(counterA.count, 30)
        XCTAssertTrue(vmA.reachedFreeLimitNotice, "30번째에는 안내해야 합니다.")
        XCTAssertTrue(defaults.bool(forKey: AppSettings.Keys.hasShownFreeLimitNotice))

        // 29 미만에서는 안내하지 않는다.
        let counterB = makeCounter(initial: 0)
        let vmB = makeVM(entitlement: FakeEntitlement(isUnlocked: false),
                         counter: counterB, defaults: makeDefaults())
        await driveToReview(vmB, text: "첫 하늘.")
        await vmB.confirmAndAnalyze()
        XCTAssertFalse(vmB.reachedFreeLimitNotice, "30번째가 아니면 안내하지 않아야 합니다.")
    }

    // MARK: - 구매 복원 문구 (F-WURMKT)

    func test_restoreMessages() async {
        let found = PurchaseController(service: FakePurchaseService(restoreFindsPurchase: true))
        let message = await found.restore()
        XCTAssertEqual(message, "평생 이용권을 다시 불러왔어요.")
        XCTAssertTrue(found.isUnlocked)

        let none = PurchaseController(service: FakePurchaseService(restoreFindsPurchase: false))
        let message2 = await none.restore()
        XCTAssertEqual(message2, "불러올 구매 내역이 없어요.")

        let failing = PurchaseController(service: FakePurchaseService(throwOnRestore: true))
        let message3 = await failing.restore()
        XCTAssertEqual(message3, "잠시 후 다시 시도해 주세요.")
    }
}
