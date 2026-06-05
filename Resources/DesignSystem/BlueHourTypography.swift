//
//  BlueHourTypography.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

extension Font {

    // MARK: - Blue Hour Typography
    // 시적이고 차분한 무드. 제목은 세리프(New York), 본문은 기본 산세리프.

    /// 하늘 카드 제목 등 가장 큰 타이틀. 예: "흐린 밤, 구름 사이 작은 빛"
    static let bhTitle = Font.system(.title, design: .serif).weight(.medium)

    /// 화면 헤더. 예: "오늘의 블루아워"
    static let bhHeadline = Font.system(.title2, design: .serif)

    /// 본문 텍스트. 일기 내용, 요약 등.
    static let bhBody = Font.system(.body, design: .default)

    /// 부드러운 안내 문구. 예: "잘 정리해서 말하지 않아도 괜찮아요."
    static let bhCaption = Font.system(.subheadline, design: .default).weight(.regular)

    /// 감정 키워드 칩 등 작은 라벨.
    static let bhLabel = Font.system(.footnote, design: .default).weight(.medium)

    /// 녹음 타이머 등 숫자 표시. 고정폭으로 흔들리지 않게.
    static let bhTimer = Font.system(.title, design: .monospaced).weight(.light)
}
