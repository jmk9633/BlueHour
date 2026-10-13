//
//  BlueHourColors.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {

    // MARK: - Blue Hour Palette (원시 색)
    // 문서의 Color Palette를 그대로 옮김. 라이트·다크 모두 같은 값을 쓴다.
    // 원시 색은 하늘 표현(날씨별 타일·카드·모션)에만 사용하고,
    // 화면 요소(배경·구분선 등)에는 아래 의미 토큰만 쓴다.

    /// #F7F2EA — 따뜻한 아이보리.
    static let bhWarmIvory = Color(hex: 0xF7F2EA)

    /// #2F3A56 — 블루아워의 밤 네이비.
    static let bhBlueHourNavy = Color(hex: 0x2F3A56)

    /// #C9D7E6 — 부드러운 안개빛 블루.
    static let bhMistBlue = Color(hex: 0xC9D7E6)

    /// #D8D6D1 — 차분한 구름빛 그레이.
    static let bhCloudGray = Color(hex: 0xD8D6D1)

    /// #AFA6C8 — 어스름의 라벤더.
    static let bhDuskLavender = Color(hex: 0xAFA6C8)

    /// #6F8FAF — 비 내리는 밤의 블루.
    static let bhRainBlue = Color(hex: 0x6F8FAF)

    /// #E9B89A — 노을빛 피치.
    static let bhSunsetPeach = Color(hex: 0xE9B89A)

    /// #303038 — 본문 텍스트용 차콜.
    static let bhSoftCharcoal = Color(hex: 0x303038)

    // MARK: - 의미 기반 토큰(Semantic) — 라이트/다크 동적
    // iOS 시스템 설정(라이트/다크)에 따라 값이 바뀐다. 앱 안에 별도 화면 모드 설정은 두지 않는다.
    // 모든 화면 요소의 색은 이 토큰만 사용한다.

    /// 화면 기본 배경 — 라이트 Warm Ivory / 다크 #1C2233
    static let bhBackground = Color(light: 0xF7F2EA, dark: 0x1C2233)

    /// 주요 텍스트 — 라이트 Soft Charcoal / 다크 Warm Ivory
    static let bhTextPrimary = Color(light: 0x303038, dark: 0xF7F2EA)

    /// 보조 텍스트 — 라이트 Navy 60% / 다크 Mist Blue 70%
    static let bhTextSecondary = Color(
        light: 0x2F3A56, lightAlpha: 0.6,
        dark: 0xC9D7E6, darkAlpha: 0.7
    )

    /// 주요 버튼/강조 요소 — 라이트 Navy / 다크 Mist Blue
    static let bhAccent = Color(light: 0x2F3A56, dark: 0xC9D7E6)

    /// 강조 위 글자(주요 버튼 글자) — 라이트 Warm Ivory / 다크 Navy
    static let bhOnAccent = Color(light: 0xF7F2EA, dark: 0x2F3A56)

    /// 카드·시트 위 면(시스템 머티리얼 대체) — 라이트 Cloud Gray 35% / 다크 Navy
    static let bhSurface = Color(
        light: 0xD8D6D1, lightAlpha: 0.35,
        dark: 0x2F3A56, darkAlpha: 1.0
    )
}

// MARK: - Hex / 동적 초기화 헬퍼

extension Color {
    /// 0xRRGGBB 형태의 정수로 Color 생성
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// 라이트/다크 trait에 따라 다른 hex를 쓰는 동적 Color
    init(light: UInt, lightAlpha: Double = 1.0, dark: UInt, darkAlpha: Double = 1.0) {
        #if canImport(UIKit)
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
        #else
        self.init(hex: light, alpha: lightAlpha)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    /// 0xRRGGBB 형태의 정수로 UIColor 생성
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
#endif
