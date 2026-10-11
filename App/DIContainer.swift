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

    // MARK: - 구매 · 무료 하늘 카운트 (6단계)

    /// 무료 하늘 카운트(키체인 저장). 새 기록 저장 시에만 증가.
    let freeSkyCounter: FreeSkyCounter
    /// 구매 상태(평생 이용권 보유 여부). 앱 실행 동안 트랜잭션 업데이트를 듣는다.
    let purchaseController: PurchaseController

    // MARK: - 리포지토리 (ModelContext 필요, 나중에 주입)

    private var modelContext: ModelContext?
    private var _diaryRepository: DiaryRepositoryProtocol?
    private var _pendingAnalyzer: PendingSkyAnalyzer?

    /// 리포지토리 접근. ModelContext가 연결되기 전에 부르면 잘못된 사용이므로 크래시.
    var diaryRepository: DiaryRepositoryProtocol {
        guard let repository = _diaryRepository else {
            fatalError("DIContainer에 ModelContext가 아직 연결되지 않았습니다. setup(modelContext:)를 먼저 호출하세요.")
        }
        return repository
    }

    /// '아직 그려지지 않은 하늘' 자동 분석기.
    var pendingAnalyzer: PendingSkyAnalyzer {
        guard let analyzer = _pendingAnalyzer else {
            fatalError("DIContainer에 ModelContext가 아직 연결되지 않았습니다. setup(modelContext:)를 먼저 호출하세요.")
        }
        return analyzer
    }

    // MARK: - 초기화

    init() {
        // 녹음 일꾼을 먼저 만들고, 음성 일꾼이 그것을 참조한다.
        let audio = AudioRecordingService()
        self.audioService = audio
        self.speechService = SpeechRecognitionService(audioService: audio)
        self.analysisService = SkyAnalysisService()

        // 무료 카운트는 키체인에, 구매 상태는 StoreKit 2로 확인한다.
        self.freeSkyCounter = FreeSkyCounter(store: KeychainFreeSkyCountStore())
        self.purchaseController = PurchaseController(service: StoreKitPurchaseService())
        // 앱 실행 즉시 구매 여부 확인·트랜잭션 청취를 시작한다.
        purchaseController.start()
    }

    // MARK: - ModelContext 연결 (앱 진입점에서 1회 호출)

    func setup(modelContext: ModelContext) {
        guard _diaryRepository == nil else { return }  // 중복 방지
        self.modelContext = modelContext
        let repository = DiaryRepository(context: modelContext)
        self._diaryRepository = repository
        self._pendingAnalyzer = PendingSkyAnalyzer(
            repository: repository,
            analysisService: analysisService
        )
    }
}
