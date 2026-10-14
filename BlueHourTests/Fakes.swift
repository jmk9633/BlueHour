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
    var available: Bool
    var deviceEligible: Bool
    var errorToThrow: Error?
    var reasonWhenUnavailable: SkyUnavailableReason?

    init(
        result: SkyAnalysis = FakeSkyAnalysisService.defaultSky,
        available: Bool = true,
        deviceEligible: Bool = true,
        errorToThrow: Error? = nil,
        reasonWhenUnavailable: SkyUnavailableReason? = nil
    ) {
        self.result = result
        self.available = available
        self.deviceEligible = deviceEligible
        self.errorToThrow = errorToThrow
        self.reasonWhenUnavailable = reasonWhenUnavailable
    }

    func isAvailable() async -> Bool { available }

    func isDeviceEligible() async -> Bool { deviceEligible }

    func unavailableReason() async -> SkyUnavailableReason? { reasonWhenUnavailable }

    func analyze(text: String) async throws -> SkyAnalysis {
        if let errorToThrow { throw errorToThrow }
        return result
    }

    static let defaultSky = SkyAnalysis(
        weatherType: .moonlight,
        title: "고요한 밤",
        summary: "잔잔하게 흘러간 하루였어요.",
        emotionKeywords: ["평온"],
        tomorrowSentence: "편안한 밤 보내요."
    )
}

// MARK: - 하늘 생성기 (오케스트레이터 테스트용)

/// 호출마다 미리 정해진 결과를 돌려주고, 호출 횟수와 reinforced 플래그를 기록한다.
actor FakeSkyGenerator: GeneratedSkyProducing {
    private let outputs: [Result<SkyAnalysis, Error>]
    private let available: Bool
    private(set) var callCount = 0
    private(set) var reinforcedFlags: [Bool] = []

    init(outputs: [Result<SkyAnalysis, Error>], available: Bool = true) {
        self.outputs = outputs
        self.available = available
    }

    func isAvailable() async -> Bool { available }

    func isDeviceEligible() async -> Bool { available }

    func unavailableReason() async -> SkyUnavailableReason? { available ? nil : .modelNotReady }

    func produce(text: String, reinforced: Bool) async throws -> SkyAnalysis {
        let index = callCount
        callCount += 1
        reinforcedFlags.append(reinforced)
        guard index < outputs.count else {
            throw SkyAnalysisError.analysisFailed
        }
        switch outputs[index] {
        case .success(let sky): return sky
        case .failure(let error): throw error
        }
    }
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

// MARK: - 무료 하늘 카운트 저장소 (인메모리)

/// 키체인 대신 메모리에 값을 둔다. 같은 인스턴스를 재사용하면 '재설치해도 유지'를 흉내낼 수 있다.
final class InMemoryFreeSkyCountStore: FreeSkyCountStoring, @unchecked Sendable {
    private var value: Int
    init(initial: Int = 0) { self.value = initial }
    func load() -> Int { value }
    func save(_ count: Int) { value = count }
}

// MARK: - 구매 여부 제공자 (게이트 테스트용)

/// 구매 여부와 '준비 완료' 시점을 제어해 입구 게이트를 결정적으로 검증한다.
@MainActor
final class FakeEntitlement: EntitlementProviding {
    var isUnlocked: Bool
    private var ready: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(isUnlocked: Bool = false, ready: Bool = true) {
        self.isUnlocked = isUnlocked
        self.ready = ready
    }

    func waitUntilReady() async {
        if ready { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// 구매 여부 확인이 끝난 것으로 표시하고, 기다리던 호출을 모두 깨운다.
    func markReady(unlocked: Bool) {
        isUnlocked = unlocked
        ready = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

// MARK: - 구매 서비스 (StoreKit 대역)

enum FakeStoreError: Error { case failed }

actor FakePurchaseService: PurchaseServiceProtocol {
    var productInfo: StoreProductInfo?
    var purchaseOutcome: PurchaseOutcome
    var restoreFindsPurchase: Bool
    var unlocked: Bool
    var throwOnRestore: Bool

    init(
        productInfo: StoreProductInfo? = StoreProductInfo(displayPrice: "₩4,400"),
        purchaseOutcome: PurchaseOutcome = .success,
        restoreFindsPurchase: Bool = false,
        unlocked: Bool = false,
        throwOnRestore: Bool = false
    ) {
        self.productInfo = productInfo
        self.purchaseOutcome = purchaseOutcome
        self.restoreFindsPurchase = restoreFindsPurchase
        self.unlocked = unlocked
        self.throwOnRestore = throwOnRestore
    }

    func product() async throws -> StoreProductInfo? { productInfo }
    func purchase() async throws -> PurchaseOutcome { purchaseOutcome }
    func restore() async throws -> Bool {
        if throwOnRestore { throw FakeStoreError.failed }
        return restoreFindsPurchase
    }
    func currentlyUnlocked() async -> Bool { unlocked }
    nonisolated func transactionUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

// MARK: - 알림 예약 (UNUserNotificationCenter 대역)

/// 권한 상태와 예약/취소를 제어·기록해 밤 리마인더 예약 로직을 결정적으로 검증한다.
@MainActor
final class FakeNotificationScheduler: NotificationScheduling {
    var status: NotificationAuthStatus
    var requestResult: Bool

    private(set) var requestCount = 0
    /// 현재 예약돼 있는(= pending) 알림들.
    private(set) var scheduled: [(identifier: String, body: String, components: DateComponents)] = []
    /// removeReminders 호출마다 전달된 식별자 목록(재예약이 먼저 취소하는지 검증용).
    private(set) var removedCalls: [[String]] = []

    init(status: NotificationAuthStatus = .authorized, requestResult: Bool = true) {
        self.status = status
        self.requestResult = requestResult
    }

    func authorizationStatus() async -> NotificationAuthStatus { status }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        if requestResult { status = .authorized }
        return requestResult
    }

    func pendingReminderIdentifiers() async -> [String] {
        scheduled.map(\.identifier)
    }

    func removeReminders(identifiers: [String]) async {
        removedCalls.append(identifiers)
        scheduled.removeAll { identifiers.contains($0.identifier) }
    }

    func scheduleReminder(identifier: String, body: String, at components: DateComponents) async {
        scheduled.append((identifier, body, components))
    }

    // 조회 헬퍼
    var scheduledIdentifiers: [String] { scheduled.map(\.identifier) }
    func hasScheduled(dateKey: String) -> Bool {
        scheduled.contains { $0.identifier.hasSuffix(dateKey) }
    }
}

// MARK: - 생체/암호 인증

/// 인증 가능 여부와 인증 성공 여부를 주입해 잠금 전환 로직을 결정적으로 검증한다.
struct FakeBiometricAuthenticator: BiometricAuthenticating {
    var canAuthenticateResult: Bool
    var authenticateResult: Bool

    init(canAuthenticate: Bool = true, authenticate: Bool = true) {
        self.canAuthenticateResult = canAuthenticate
        self.authenticateResult = authenticate
    }

    func canAuthenticate() -> Bool { canAuthenticateResult }
    func authenticate(reason: String) async -> Bool { authenticateResult }
}
