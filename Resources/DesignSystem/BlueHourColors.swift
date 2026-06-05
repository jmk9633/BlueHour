//
//  BlueHourColors.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

extension Color {

    // MARK: - Blue Hour Palette
    // 문서의 Color Palette를 그대로 옮김. 화면에서는 이 이름으로만 사용한다.

    /// #F7F2EA — 배경 기본색. 따뜻한 아이보리.
    static let bhWarmIvory = Color(hex: 0xF7F2EA)

    /// #2F3A56 — 핵심 강조색. 블루아워의 밤 네이비.
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

    // MARK: - 의미 기반 별칭(Semantic)
    // 색의 "역할"로 부르면 나중에 팔레트를 바꿔도 화면 코드를 안 고쳐도 된다.

    /// 화면 기본 배경
    static let bhBackground = bhWarmIvory
    /// 주요 텍스트
    static let bhTextPrimary = bhSoftCharcoal
    /// 보조 텍스트
    static let bhTextSecondary = bhBlueHourNavy.opacity(0.6)
    /// 주요 버튼/강조 요소
    static let bhAccent = bhBlueHourNavy
}

// MARK: - Hex 초기화 헬퍼

extension Color {
    /// 0xRRGGBB 형태의 정수로 Color 생성
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
