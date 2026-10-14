//
//  PendingSkyAnalyzerTests.swift
//  BlueHourTests
//
//  '아직 그려지지 않은 하늘' 자동 분석 검증. (S-EMLDBO / F-LLFPXL)
//  - AI를 쓸 수 없으면 시작하지 않는다.
//  - 날짜순으로 하나씩 분석해 채운다.
//  - 이미 분석된 기록·빈 글은 건너뛴다.
//  - 한 기록이 실패해도 다른 기록은 계속 처리한다.
//  - 분석 도중 사용자가 그 기록을 바꿨으면(updatedAt 변경) 건너뛴다.
//

import XCTest
@testable import BlueHour

@MainActor
final class PendingSkyAnalyzerTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    private func day(_ d: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 5, day: d))!
    }

    private func sky(_ title: String) -> SkyAnalysis {
        SkyAnalysis(weatherType: .moonlight, title: title, summary: "요약", emotionKeywords: ["평온"], tomorrowSentence: "편안한 밤 보내요.")
    }

    private func undrawn(day d: Int, text: String = "오늘 하루 이야기") -> DiaryEntry {
        DiaryEntry(date: day(d), recording: nil, transcript: DiaryTranscript(originalText: text), analysis: nil)
    }

    // MARK: - 날짜순으로 하나씩 채운다

    func test_pendingEntries를_날짜순으로_채운다() async throws {
        let repo = FakeDiaryRepository(seed: [undrawn(day: 3), undrawn(day: 1), undrawn(day: 2)])
        let service = HookAnalysis(available: true)
        let analyzer = PendingSkyAnalyzer(repository: repo, analysisService: service)

        await analyzer.run()

        let all = try await repo.fetchAll()
        XCTAssertTrue(all.allSatisfy { $0.analysis != nil }, "모든 미그림 기록이 분석돼야 합니다.")
        let updatedDates = await repo.updated.map { $0.date }
        XCTAssertEqual(updatedDates, [day(1), day(2), day(3)], "날짜 오름차순으로 분석해야 합니다.")
    }

    // MARK: - AI를 쓸 수 없으면 시작하지 않는다

    func test_AI를_쓸수없으면_아무것도_안한다() async {
        let repo = FakeDiaryRepository(seed: [undrawn(day: 1)])
        let service = HookAnalysis(available: false)
        let analyzer = PendingSkyAnalyzer(repository: repo, analysisService: service)

        await analyzer.run()

        let updatedCount = await repo.updated.count
        XCTAssertEqual(updatedCount, 0)
    }

    // MARK: - 이미 분석된 기록·빈 글은 건너뛴다

    func test_이미분석됨과_빈글은_건너뛴다() async {
        let drawn = DiaryEntry(date: day(1), recording: nil,
                               transcript: DiaryTranscript(originalText: "이미 그려짐"),
                               analysis: sky("이미 있는 하늘"))
        let empty = DiaryEntry(date: day(2), recording: nil,
                               transcript: DiaryTranscript(originalText: ""), analysis: nil)
        let repo = FakeDiaryRepository(seed: [drawn, empty, undrawn(day: 3)])
        let service = HookAnalysis(available: true)
        let analyzer = PendingSkyAnalyzer(repository: repo, analysisService: service)

        await analyzer.run()

        let updated = await repo.updated
        XCTAssertEqual(updated.count, 1, "미그림이고 글이 있는 기록 하나만 분석돼야 합니다.")
        XCTAssertEqual(updated.first?.date, day(3))
    }

    // MARK: - 한 기록이 실패해도 다른 기록은 계속 처리한다

    func test_하나_실패해도_나머지는_계속_처리() async throws {
        let repo = FakeDiaryRepository(seed: [undrawn(day: 1, text: "fail"), undrawn(day: 2, text: "ok")])
        let service = HookAnalysis(available: true, failTexts: ["fail"])
        let analyzer = PendingSkyAnalyzer(repository: repo, analysisService: service)

        await analyzer.run()

        let all = try await repo.fetchAll()
        let d1 = all.first { $0.date == self.day(1) }
        let d2 = all.first { $0.date == self.day(2) }
        XCTAssertNil(d1?.analysis, "실패한 기록은 미완성으로 남아야 합니다.")
        XCTAssertNotNil(d2?.analysis, "다른 기록은 계속 처리돼야 합니다.")
    }

    // MARK: - 분석 도중 사용자가 그 기록을 바꾸면 건너뛴다

    func test_분석중_사용자수정시_그기록은_건너뛴다() async throws {
        let target = undrawn(day: 1)
        let repo = FakeDiaryRepository(seed: [target])
        // 분석 결과를 돌려주기 직전에 사용자가 같은 기록을 수정(updatedAt 변경)한 것으로 흉내낸다.
        let service = HookAnalysis(available: true) { [repo] in
            var edited = target
            edited.updatedAt = target.updatedAt.addingTimeInterval(10)
            try? await repo.update(edited)
        }
        let analyzer = PendingSkyAnalyzer(repository: repo, analysisService: service)

        await analyzer.run()

        let current = try await repo.fetch(id: target.id)
        XCTAssertNil(current?.analysis, "분석 도중 바뀐 기록에는 자동 분석 결과를 덮어쓰면 안 됩니다.")
    }
}

// MARK: - 테스트용 분석 서비스 (텍스트별 실패·분석 직전 훅 지원)

private actor HookAnalysis: SkyAnalysisServiceProtocol {
    let available: Bool
    let failTexts: Set<String>
    let hook: (@Sendable () async -> Void)?

    init(available: Bool, failTexts: Set<String> = [], hook: (@Sendable () async -> Void)? = nil) {
        self.available = available
        self.failTexts = failTexts
        self.hook = hook
    }

    func isAvailable() async -> Bool { available }
    func isDeviceEligible() async -> Bool { true }
    func unavailableReason() async -> SkyUnavailableReason? { available ? nil : .modelNotReady }

    func analyze(text: String) async throws -> SkyAnalysis {
        if failTexts.contains(text) { throw SkyAnalysisError.analysisFailed }
        if let hook { await hook() }
        return SkyAnalysis(weatherType: .moonlight, title: "자동 분석", summary: "요약",
                           emotionKeywords: ["평온"], tomorrowSentence: "편안한 밤 보내요.")
    }
}
