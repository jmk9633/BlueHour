//
//  PendingSkyAnalyzer.swift
//  BlueHour
//
//  '아직 그려지지 않은 하늘'(analysis == nil)을 AI를 쓸 수 있게 됐을 때 자동으로 분석한다.
//  앱 실행·포그라운드 복귀 시 호출한다. (F-LLFPXL / PL-FUVSGO)
//
//  규칙:
//   - AI를 쓸 수 없으면 아예 시작하지 않는다.
//   - 실행이 겹쳐도 한 번에 하나만 돈다(중복 실행 방지).
//   - 분석하는 동안 사용자가 그 기록을 수정·다시 말하기·삭제했으면 그 기록은 건너뛴다.
//

import Foundation

@MainActor
final class PendingSkyAnalyzer {

    private let repository: DiaryRepositoryProtocol
    private let analysisService: SkyAnalysisServiceProtocol

    /// 중복 실행 방지 플래그. (앱 실행과 포그라운드 복귀가 겹쳐도 한 번만)
    private var isRunning = false

    init(repository: DiaryRepositoryProtocol, analysisService: SkyAnalysisServiceProtocol) {
        self.repository = repository
        self.analysisService = analysisService
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // AI를 쓸 수 없으면 시작하지 않는다.
        guard await analysisService.isAvailable() else { return }

        let all = (try? await repository.fetchAll()) ?? []
        let pending = all
            .filter { $0.analysis == nil && !($0.transcript?.displayText ?? "").isEmpty }
            .sorted { $0.date < $1.date }

        for entry in pending {
            let text = entry.transcript?.displayText ?? ""
            guard let sky = try? await analysisService.analyze(text: text) else {
                // 실패한 기록은 다음 실행 때 다시 시도
                continue
            }

            // 분석하는 동안 사용자가 바꿨/지웠는지 저장 직전에 재확인한다.
            let currentOptional = try? await repository.fetch(id: entry.id)
            guard let current = currentOptional ?? nil else {
                continue   // 삭제됨 → 건너뜀
            }
            guard current.analysis == nil, current.updatedAt == entry.updatedAt else {
                continue   // 수정·다시 말하기로 바뀜 → 건너뜀
            }

            var updated = current
            updated.analysis = sky
            updated.updatedAt = BlueHourClock.now()
            try? await repository.update(updated)
        }
    }
}
