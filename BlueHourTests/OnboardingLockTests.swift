//
//  OnboardingLockTests.swift
//  BlueHourTests
//
//  5단계(첫 실행 안내 + 프라이버시) 유닛 테스트.
//  - 첫 실행 완료 여부 / 음성 저장 방식 초기값 / 첫 실행 안내 단계 구성
//  - Face ID 잠금 상태 전환 로직 (백그라운드/복귀/인증 성공·실패/암호 삭제)
//  - 나 탭에서 잠금 켜기 인증 게이트
//

import XCTest
@testable import BlueHour

@MainActor
final class OnboardingLockTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    // MARK: - 음성 저장 방식 초기값 (AppSettings)

    func test_registerDefaults_음성저장기본값은_목소리남기기_true() {
        let defaults = makeDefaults()
        AppSettings.registerDefaults(defaults)

        XCTAssertTrue(defaults.bool(forKey: AppSettings.Keys.saveOriginalAudio))
        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.useFaceIDLock))
        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.hasCompletedOnboarding))
    }

    // MARK: - 첫 실행 안내 (OnboardingViewModel)

    func test_onboarding_keepVoice_기본값은_true() {
        let vm = OnboardingViewModel(defaults: makeDefaults())
        XCTAssertTrue(vm.keepVoice)
    }

    func test_onboarding_complete_목소리남기기면_saveOriginalAudio_true와_완료기록() {
        let defaults = makeDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        vm.keepVoice = true

        vm.complete()

        XCTAssertTrue(defaults.bool(forKey: AppSettings.Keys.saveOriginalAudio))
        XCTAssertTrue(defaults.bool(forKey: AppSettings.Keys.hasCompletedOnboarding))
    }

    func test_onboarding_complete_글과하늘만이면_saveOriginalAudio_false() {
        let defaults = makeDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        vm.keepVoice = false

        vm.complete()

        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.saveOriginalAudio))
        XCTAssertTrue(defaults.bool(forKey: AppSettings.Keys.hasCompletedOnboarding))
    }

    func test_onboarding_완료전에는_hasCompletedOnboarding_false() {
        let defaults = makeDefaults()
        let vm = OnboardingViewModel(defaults: defaults)
        vm.advance()   // intro -> audioChoice (도중)

        // complete()를 부르지 않았으므로 완료로 기록되지 않는다 → 다음 실행 때 처음부터.
        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.hasCompletedOnboarding))
    }

    func test_onboarding_지원기기_AI꺼짐이어도_③단계없음() {
        let vm = OnboardingViewModel(defaults: makeDefaults())
        vm.deviceNotEligible = false   // 지원 기기(AI 꺼짐·준비중 포함)

        XCTAssertFalse(vm.isLastStep)          // ① intro
        vm.advance()
        XCTAssertEqual(vm.step, .audioChoice)  // ②
        XCTAssertTrue(vm.isLastStep)           // ②가 마지막 → ③ 없음
    }

    func test_onboarding_미지원기기면_③단계포함() {
        let vm = OnboardingViewModel(defaults: makeDefaults())
        vm.deviceNotEligible = true    // 하드웨어 미지원(deviceNotEligible)

        vm.advance()                           // ① -> ②
        XCTAssertEqual(vm.step, .audioChoice)
        XCTAssertFalse(vm.isLastStep)          // 뒤에 ③이 붙으므로 마지막 아님
        vm.advance()                           // ② -> ③
        XCTAssertEqual(vm.step, .aiNotice)
        XCTAssertTrue(vm.isLastStep)
    }

    // MARK: - 잠금 상태 전환 (AppLockController)

    private func makeLockDefaults(enabled: Bool) -> UserDefaults {
        let defaults = makeDefaults()
        defaults.set(enabled, forKey: AppSettings.Keys.useFaceIDLock)
        return defaults
    }

    func test_lock_초기상태는_잠금설정을_따른다() {
        let onDefaults = makeLockDefaults(enabled: true)
        let offDefaults = makeLockDefaults(enabled: false)

        XCTAssertTrue(AppLockController(authenticator: FakeBiometricAuthenticator(), defaults: onDefaults).isLocked)
        XCTAssertFalse(AppLockController(authenticator: FakeBiometricAuthenticator(), defaults: offDefaults).isLocked)
    }

    func test_lock_백그라운드진입_잠금켜짐이면_즉시잠그고_복귀표시() {
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(),
            defaults: makeLockDefaults(enabled: true)
        )
        lock.enterBackground()

        XCTAssertTrue(lock.isLocked)
        XCTAssertTrue(lock.consumeBackgroundReturn())   // 한 번은 true
        XCTAssertFalse(lock.consumeBackgroundReturn())  // 소비 후 false
    }

    func test_lock_백그라운드진입_잠금꺼짐이면_잠그지않음() {
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(),
            defaults: makeLockDefaults(enabled: false)
        )
        lock.enterBackground()

        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.consumeBackgroundReturn())
    }

    func test_lock_inactive는_잠금상태를_바꾸지않는다() async {
        // 해제된 상태에서 .inactive(=enterBackground 호출 없음)로 전환돼도 잠기지 않는다.
        // (앱 전환기 덮개는 View가 담당하고, isLocked는 그대로다.)
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(authenticate: true),
            defaults: makeLockDefaults(enabled: true)
        )
        await lock.authenticateIfNeeded()
        XCTAssertFalse(lock.isLocked)

        // .inactive 모사: 아무 전환 메서드도 호출하지 않는다.
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.consumeBackgroundReturn())  // 재인증도 유발하지 않음
    }

    func test_lock_인증성공하면_해제() async {
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(authenticate: true),
            defaults: makeLockDefaults(enabled: true)
        )
        await lock.authenticateIfNeeded()
        XCTAssertFalse(lock.isLocked)
    }

    func test_lock_인증실패하면_잠긴채유지() async {
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(authenticate: false),
            defaults: makeLockDefaults(enabled: true)
        )
        await lock.authenticateIfNeeded()
        XCTAssertTrue(lock.isLocked)   // 실패 → 잠긴 채 유지
    }

    func test_lock_재시도에서_인증성공하면_해제() async {
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(authenticate: true),
            defaults: makeLockDefaults(enabled: true)
        )
        await lock.retry()
        XCTAssertFalse(lock.isLocked)
    }

    func test_lock_암호삭제로_인증불가면_잠금풀고_설정도끈다() async {
        let defaults = makeLockDefaults(enabled: true)
        let lock = AppLockController(
            authenticator: FakeBiometricAuthenticator(canAuthenticate: false),
            defaults: defaults
        )
        XCTAssertTrue(lock.isLocked)   // 시작은 잠김

        await lock.authenticateIfNeeded()

        XCTAssertFalse(lock.isLocked)  // 인증 불가 → 잠금 해제
        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.useFaceIDLock))  // 설정도 꺼짐
    }

    // MARK: - 나 탭에서 잠금 켜기 (SettingsViewModel)

    private func makeSettingsVM(
        authenticator: BiometricAuthenticating,
        defaults: UserDefaults
    ) -> SettingsViewModel {
        SettingsViewModel(
            repository: FakeDiaryRepository(),
            audioService: AudioRecordingService(),
            freeSkyCounter: FreeSkyCounter(store: InMemoryFreeSkyCountStore()),
            purchaseController: PurchaseController(service: FakePurchaseService()),
            authenticator: authenticator,
            defaults: defaults
        )
    }

    func test_설정_잠금켜기_인증성공하면_켜진다() async {
        let defaults = makeDefaults()
        let vm = makeSettingsVM(
            authenticator: FakeBiometricAuthenticator(authenticate: true),
            defaults: defaults
        )
        await vm.requestFaceIDLock(true)

        XCTAssertTrue(vm.useFaceIDLock)
        XCTAssertTrue(defaults.bool(forKey: AppSettings.Keys.useFaceIDLock))
    }

    func test_설정_잠금켜기_인증실패하면_꺼진채유지() async {
        let defaults = makeDefaults()
        let vm = makeSettingsVM(
            authenticator: FakeBiometricAuthenticator(authenticate: false),
            defaults: defaults
        )
        await vm.requestFaceIDLock(true)

        XCTAssertFalse(vm.useFaceIDLock)
        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.useFaceIDLock))
    }

    func test_설정_잠금켜기_암호없으면_안내띄우고_꺼진채유지() async {
        let defaults = makeDefaults()
        let vm = makeSettingsVM(
            authenticator: FakeBiometricAuthenticator(canAuthenticate: false),
            defaults: defaults
        )
        await vm.requestFaceIDLock(true)

        XCTAssertTrue(vm.showLockUnavailableAlert)
        XCTAssertFalse(vm.useFaceIDLock)
        XCTAssertFalse(defaults.bool(forKey: AppSettings.Keys.useFaceIDLock))
    }
}
