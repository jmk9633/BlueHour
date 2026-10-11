//
//  SettingsViewModel.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - 설정값 (UserDefaults에 저장)

    /// Face ID 잠금 사용 여부. 켜기는 인증을 거쳐야 하므로 직접 set하지 않고 requestFaceIDLock(_:)로만 바꾼다.
    private(set) var useFaceIDLock: Bool

    var saveOriginalAudio: Bool {
        didSet { defaults.set(saveOriginalAudio, forKey: AppSettings.Keys.saveOriginalAudio) }
    }

    private(set) var showDeleteConfirmation = false

    /// 기기에 Face ID·암호가 모두 없어 잠금을 켤 수 없을 때 띄우는 안내.
    var showLockUnavailableAlert = false

    // MARK: - 의존성

    private let repository: DiaryRepositoryProtocol
    private let audioService: AudioRecordingService
    private let authenticator: BiometricAuthenticating
    private let defaults: UserDefaults
    private let freeSkyCounter: FreeSkyCounter
    let purchaseController: PurchaseController

    init(
        repository: DiaryRepositoryProtocol,
        audioService: AudioRecordingService,
        freeSkyCounter: FreeSkyCounter,
        purchaseController: PurchaseController,
        authenticator: BiometricAuthenticating = BiometricAuthenticator(),
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.audioService = audioService
        self.freeSkyCounter = freeSkyCounter
        self.purchaseController = purchaseController
        self.authenticator = authenticator
        self.defaults = defaults
        // 기본값은 AppSettings.registerDefaults로 등록된다 (saveOriginalAudio = true).
        self.useFaceIDLock = defaults.bool(forKey: AppSettings.Keys.useFaceIDLock)
        self.saveOriginalAudio = defaults.bool(forKey: AppSettings.Keys.saveOriginalAudio)
    }

    // MARK: - Face ID 잠금 켜기/끄기

    /// 토글 조작에 대응한다.
    /// - 켤 때: 기기에 Face ID·암호가 없으면 안내만 띄우고 꺼진 채 둔다.
    ///          가능하면 한 번 인증하고, 성공했을 때만 켠다(실패 시 꺼진 채 유지).
    /// - 끌 때: 즉시 끈다.
    func requestFaceIDLock(_ on: Bool) async {
        guard on else {
            setLock(false)
            return
        }
        guard authenticator.canAuthenticate() else {
            showLockUnavailableAlert = true
            setLock(false)
            return
        }
        let success = await authenticator.authenticate(reason: "잠금을 켜기 위해 인증해 주세요.")
        setLock(success)
    }

    private func setLock(_ value: Bool) {
        useFaceIDLock = value
        defaults.set(value, forKey: AppSettings.Keys.useFaceIDLock)
    }

    // MARK: - 구매 · 무료 하늘 카운트 (F-XUQOXA / F-WURMKT)

    /// 평생 이용권 보유 여부. true면 카운트를 숨기고 '평생 이용 중'만 표시한다.
    var isUnlocked: Bool { purchaseController.isUnlocked }

    /// 지금까지 새로 만든 무료 하늘 수.
    var freeCount: Int { freeSkyCounter.count }

    /// 무료 하늘 한도(30).
    var freeLimit: Int { freeSkyCounter.limit }

    /// 구매 복원. 결과 안내 문구를 돌려준다. (F-WURMKT display 그대로)
    func restore() async -> String {
        await purchaseController.restore()
    }

    // MARK: - 기록 전체 삭제

    func requestDeleteAll() {
        showDeleteConfirmation = true
    }

    func cancelDelete() {
        showDeleteConfirmation = false
    }

    func confirmDeleteAll() async {
        showDeleteConfirmation = false
        try? await repository.deleteAll()
        // SwiftData 기록과 함께 Documents/Recordings의 음성 파일도 모두 삭제한다.
        try? await audioService.deleteAllRecordings()
    }
}
