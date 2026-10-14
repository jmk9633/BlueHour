//
//  DomainSafetyTests.swift
//  BlueHourTests
//
//  - 모델이 돌려준 알 수 없는 weatherType → partlyCloudy 대체 (F-MEASPV / PL-XNEFLR)
//  - 음성 인식 continuation 이중 호출 방지(ResumeGuard) (F-NYZPTM)
//

import XCTest
@testable import BlueHour

final class DomainSafetyTests: XCTestCase {

    // MARK: - weatherType 대체

    func test_알수없는_weatherType은_partlyCloudy로_대체된다() {
        XCTAssertEqual(SkyWeatherType(fromModelRawValue: "nonsense"), .partlyCloudy)
        XCTAssertEqual(SkyWeatherType(fromModelRawValue: ""), .partlyCloudy)
    }

    func test_유효한_weatherType_10종은_그대로_유지된다() {
        for type in SkyWeatherType.allCases {
            XCTAssertEqual(SkyWeatherType(fromModelRawValue: type.rawValue), type)
        }
    }

    // MARK: - ResumeGuard (continuation 이중 호출 방지)

    func test_ResumeGuard는_처음에만_true를_돌려준다() async {
        let guardActor = ResumeGuard()
        let first = await guardActor.markIfNeeded()
        let second = await guardActor.markIfNeeded()
        let third = await guardActor.markIfNeeded()
        XCTAssertTrue(first, "첫 호출은 true여야 합니다.")
        XCTAssertFalse(second, "두 번째 호출은 false여야 합니다(이중 resume 방지).")
        XCTAssertFalse(third)
    }

    func test_ResumeGuard는_동시호출에도_한번만_true() async {
        let guardActor = ResumeGuard()
        // 여러 작업이 동시에 markIfNeeded를 불러도 true는 정확히 한 번만 나와야 한다.
        async let a = guardActor.markIfNeeded()
        async let b = guardActor.markIfNeeded()
        async let c = guardActor.markIfNeeded()
        async let d = guardActor.markIfNeeded()
        let results = await [a, b, c, d]
        XCTAssertEqual(results.filter { $0 }.count, 1, "true는 정확히 한 번만 나와야 합니다.")
    }
}
