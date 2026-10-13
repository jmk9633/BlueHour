//
//  DesignTokenTests.swift
//  BlueHourTests
//
//  9단계 다크 모드. 의미 토큰 6개가 라이트·다크 trait에서 기대 색으로 풀리는지,
//  날씨 10종 카드 글자색이 Ivory 바탕 합성 → 다크 10% 덮개 → 스크림 적용 후
//  라이트·다크 모두 대비 4.5:1 이상인지 검증한다. (F-JPRZPV / F-QMDQQQ)
//

import XCTest
import SwiftUI
@testable import BlueHour

final class DesignTokenTests: XCTestCase {

    // MARK: - 보조: 동적 Color를 trait에 맞춰 RGBA로 해석

    private func resolved(_ color: Color, dark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let trait = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let ui = UIColor(color).resolvedColor(with: trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func assertColor(
        _ color: Color,
        dark: Bool,
        hex: UInt,
        alpha: CGFloat = 1.0,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let got = resolved(color, dark: dark)
        let er = CGFloat((hex >> 16) & 0xFF) / 255.0
        let eg = CGFloat((hex >> 8) & 0xFF) / 255.0
        let eb = CGFloat(hex & 0xFF) / 255.0
        let tol: CGFloat = 0.01
        XCTAssertEqual(got.r, er, accuracy: tol, "\(label) R (dark=\(dark))", file: file, line: line)
        XCTAssertEqual(got.g, eg, accuracy: tol, "\(label) G (dark=\(dark))", file: file, line: line)
        XCTAssertEqual(got.b, eb, accuracy: tol, "\(label) B (dark=\(dark))", file: file, line: line)
        XCTAssertEqual(got.a, alpha, accuracy: tol, "\(label) A (dark=\(dark))", file: file, line: line)
    }

    // MARK: - 의미 토큰 6개 라이트/다크 해석

    func test_bhBackground_lightAndDark() {
        assertColor(.bhBackground, dark: false, hex: 0xF7F2EA, "bhBackground 라이트")
        assertColor(.bhBackground, dark: true, hex: 0x1C2233, "bhBackground 다크")
    }

    func test_bhTextPrimary_lightAndDark() {
        assertColor(.bhTextPrimary, dark: false, hex: 0x303038, "bhTextPrimary 라이트")
        assertColor(.bhTextPrimary, dark: true, hex: 0xF7F2EA, "bhTextPrimary 다크")
    }

    func test_bhTextSecondary_lightAndDark() {
        assertColor(.bhTextSecondary, dark: false, hex: 0x2F3A56, alpha: 0.6, "bhTextSecondary 라이트")
        assertColor(.bhTextSecondary, dark: true, hex: 0xC9D7E6, alpha: 0.7, "bhTextSecondary 다크")
    }

    func test_bhAccent_lightAndDark() {
        assertColor(.bhAccent, dark: false, hex: 0x2F3A56, "bhAccent 라이트")
        assertColor(.bhAccent, dark: true, hex: 0xC9D7E6, "bhAccent 다크")
    }

    func test_bhOnAccent_lightAndDark() {
        assertColor(.bhOnAccent, dark: false, hex: 0xF7F2EA, "bhOnAccent 라이트")
        assertColor(.bhOnAccent, dark: true, hex: 0x2F3A56, "bhOnAccent 다크")
    }

    func test_bhSurface_lightAndDark() {
        assertColor(.bhSurface, dark: false, hex: 0xD8D6D1, alpha: 0.35, "bhSurface 라이트")
        assertColor(.bhSurface, dark: true, hex: 0x2F3A56, alpha: 1.0, "bhSurface 다크")
    }

    // MARK: - 날씨 10종 카드 글자색 대비 4.5:1 이상 (라이트·다크)

    func test_cardTextContrast_meetsWCAG_lightAndDark() {
        for weather in SkyWeatherType.allCases {
            let light = weather.minCardTextContrast(dark: false)
            let dark = weather.minCardTextContrast(dark: true)
            XCTAssertGreaterThanOrEqual(
                light, 4.5,
                "\(weather.displayName) 라이트 대비 \(String(format: "%.2f", light))"
            )
            XCTAssertGreaterThanOrEqual(
                dark, 4.5,
                "\(weather.displayName) 다크 대비 \(String(format: "%.2f", dark))"
            )
        }
    }
}
