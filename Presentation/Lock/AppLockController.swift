//
//  AppLockController.swift
//  BlueHour
//
//  Face ID 잠금(F-TNEYMY)의 상태 전환을 담당한다.
//  - 잠금 설정(useFaceIDLock)이 켜져 있으면 앱 진입·백그라운드 복귀 시 인증을 요구한다.
//  - isLocked 전환은 '백그라운드 진입'에서만 일어난다. (.inactive로는 잠그지 않는다 — 앱 전환기 덮개는 View가 담당)
//  - Face ID 팝업으로 생기는 .inactive→.active 복귀에서는 재인증하지 않는다(consumeBackgroundReturn).
//  - 기기 암호가 삭제되어 인증 자체가 불가능해지면 잠금을 풀고 설정도 끈다.
//

import Foundation
import Observation
import LocalAuthentication

// MARK: - 생체/암호 인증 추상화 (테스트에서 가짜로 대체)

protocol BiometricAuthenticating: Sendable {
    /// 지금 기기에서 인증(Face ID 또는 기기 암호)이 가능한지.
    func canAuthenticate() -> Bool
    /// 인증을 수행한다. 성공하면 true.
    func authenticate(reason: String) async -> Bool
}

/// LocalAuthentication 기반 실제 구현.
/// Face ID가 실패해도 기기 암호로 풀 수 있도록 .deviceOwnerAuthentication 정책을 쓴다.
struct BiometricAuthenticator: BiometricAuthenticating {

    func canAuthenticate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

// MARK: - 잠금 컨트롤러

@MainActor
@Observable
final class AppLockController {

    /// 내용이 잠겨 있는지. true면 루트 화면이 잠금 화면을 덮는다.
    private(set) var isLocked: Bool
    /// 인증이 진행 중인지. 중복 호출을 막는 데 쓴다.
    private(set) var isAuthenticating = false

    /// '백그라운드에서 돌아온 복귀'인지 표시하는 플래그.
    /// Face ID 팝업으로 인한 .inactive→.active 복귀에서는 세워지지 않아 재인증을 막는다.
    private var pendingBackgroundReturn = false

    private let authenticator: BiometricAuthenticating
    private let defaults: UserDefaults

    private static let reason = "오늘의 기록을 나만 볼 수 있도록 Face ID로 잠가요."

    init(
        authenticator: BiometricAuthenticating = BiometricAuthenticator(),
        defaults: UserDefaults = .standard
    ) {
        self.authenticator = authenticator
        self.defaults = defaults
        // 콜드 런치 시, 잠금이 켜져 있으면 잠긴 상태로 시작한다.
        self.isLocked = defaults.bool(forKey: AppSettings.Keys.useFaceIDLock)
    }

    /// 지금 잠금 설정이 켜져 있는지. (설정 화면에서 바뀔 수 있으므로 매번 defaults를 읽는다.)
    private var lockEnabled: Bool {
        defaults.bool(forKey: AppSettings.Keys.useFaceIDLock)
    }

    // MARK: - 인증

    /// 잠겨 있으면 인증을 시도한다. 콜드 런치(.task)와 백그라운드 복귀에서 호출한다.
    func authenticateIfNeeded() async {
        guard lockEnabled, isLocked, !isAuthenticating else { return }

        // 기기 암호가 삭제되어 인증 자체가 불가능하면, 사용자가 영영 못 들어가지 않도록
        // 잠금을 풀고 설정도 끈다.
        guard authenticator.canAuthenticate() else {
            disableLock()
            return
        }

        isAuthenticating = true
        let success = await authenticator.authenticate(reason: Self.reason)
        isAuthenticating = false
        if success {
            isLocked = false
        }
    }

    /// 잠금 화면의 '다시 시도' 버튼.
    func retry() async {
        await authenticateIfNeeded()
    }

    // MARK: - 장면 전환

    /// 백그라운드 진입: 잠금이 켜져 있으면 즉시 잠그고, 복귀 시 재인증하도록 표시한다.
    func enterBackground() {
        guard lockEnabled else { return }
        isLocked = true
        pendingBackgroundReturn = true
    }

    /// 이번 .active 복귀가 '백그라운드에서 돌아온 것'인지 한 번 소비한다.
    /// (Face ID 팝업으로 생긴 .inactive→.active 복귀에서는 false라 재인증하지 않는다.)
    func consumeBackgroundReturn() -> Bool {
        defer { pendingBackgroundReturn = false }
        return pendingBackgroundReturn
    }

    // MARK: - 내부

    /// 인증이 불가능해진 경우: 잠금을 풀고 설정도 끈다.
    private func disableLock() {
        isLocked = false
        defaults.set(false, forKey: AppSettings.Keys.useFaceIDLock)
    }
}
