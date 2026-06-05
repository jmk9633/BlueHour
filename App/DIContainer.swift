//
//  DIContainer.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

/// 앱의 모든 일꾼(서비스/리포지토리)을 모아두는 관리실.
/// 화면(ViewModel)은 여기서 필요한 일꾼을 받아 쓴다.
@MainActor
final class DIContainer {

    // MARK: - 서비스 (ModelContext 불필요, 앱 시작 시 바로 생성)

    let audioService: AudioRecordingService
    let speechService: SpeechRecognitionService
    let analysisService: SkyAnalysisService

    // MARK: - 리포지토리 (ModelContext 필요, 나중에 주입)

    private var modelContext: ModelContext?
    private var _diaryRepository: DiaryRepositoryProtocol?

    /// 리포지토리 접근. ModelContext가 연결되기 전에 부르면 잘못된 사용이므로 크래시.
    var diaryRepository: DiaryRepositoryProtocol {
        guard let repository = _diaryRepository else {
            fatalError("DIContainer에 ModelContext가 아직 연결되지 않았습니다. setup(modelContext:)를 먼저 호출하세요.")
        }
        return repository
    }

    // MARK: - 초기화

    init() {
        // 녹음 일꾼을 먼저 만들고, 음성 일꾼이 그것을 참조한다.
        let audio = AudioRecordingService()
        self.audioService = audio
        self.speechService = SpeechRecognitionService(audioService: audio)
        self.analysisService = SkyAnalysisService()
    }

    // MARK: - ModelContext 연결 (앱 진입점에서 1회 호출)

    func setup(modelContext: ModelContext) {
        guard _diaryRepository == nil else { return }  // 중복 방지
        self.modelContext = modelContext
        self._diaryRepository = DiaryRepository(context: modelContext)
    }
}
