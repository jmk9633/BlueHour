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
        didSet { defaults.set(useFaceIDLock, forKey: AppSettings.Keys.useFaceIDLock) }
    }

    var saveOriginalAudio: Bool {
        didSet { defaults.set(saveOriginalAudio, forKey: AppSettings.Keys.saveOriginalAudio) }
    }

    private(set) var showDeleteConfirmation = false

    // MARK: - 의존성

    private let repository: DiaryRepositoryProtocol
    private let audioService: AudioRecordingService
    private let defaults: UserDefaults

    init(
        repository: DiaryRepositoryProtocol,
        audioService: AudioRecordingService,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.audioService = audioService
        self.defaults = defaults
        // 기본값은 AppSettings.registerDefaults로 등록된다 (saveOriginalAudio = true).
        self.useFaceIDLock = defaults.bool(forKey: AppSettings.Keys.useFaceIDLock)
        self.saveOriginalAudio = defaults.bool(forKey: AppSettings.Keys.saveOriginalAudio)
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
