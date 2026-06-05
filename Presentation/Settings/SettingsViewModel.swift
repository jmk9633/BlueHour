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

    var useFaceIDLock: Bool {
        didSet { defaults.set(useFaceIDLock, forKey: Keys.faceID) }
    }

    var saveOriginalAudio: Bool {
        didSet { defaults.set(saveOriginalAudio, forKey: Keys.saveAudio) }
    }

    private(set) var showDeleteConfirmation = false

    // MARK: - 의존성

    private let repository: DiaryRepositoryProtocol
    private let defaults: UserDefaults

    private enum Keys {
        static let faceID = "settings.useFaceIDLock"
        static let saveAudio = "settings.saveOriginalAudio"
    }

    init(repository: DiaryRepositoryProtocol, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
        self.useFaceIDLock = defaults.bool(forKey: Keys.faceID)
        // 기본값: 원본 음성 저장 안 함 (문서 정책)
        self.saveOriginalAudio = defaults.bool(forKey: Keys.saveAudio)
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
    }
}
