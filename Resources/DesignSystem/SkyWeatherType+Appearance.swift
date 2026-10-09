//
//  SkyWeatherType+Appearance.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

extension SkyWeatherType {

    /// 달력에서 이 하늘을 나타낼 색 (무드보드 조각)
    var tileColor: Color {
        switch self {
        case .clearNight:        return .bhBlueHourNavy
        case .partlyCloudy:      return .bhRainBlue.opacity(0.6)
        case .cloudyNight:       return .bhCloudGray
        case .lightRain:         return .bhRainBlue
        case .shower:            return .bhRainBlue.opacity(0.85)
        case .fog:               return .bhMistBlue
        case .windy:             return .bhMistBlue.opacity(0.7)
        case .sunset:            return .bhSunsetPeach
        case .moonlight:         return .bhDuskLavender
        case .lightThroughClouds: return .bhDuskLavender.opacity(0.6)
        }
    }

    /// 결과 카드 배경에 쓰는 날씨 유형별 그라데이션. 디자인 토큰 색만 조합한다.
    var cardGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .clearNight:
            colors = [.bhBlueHourNavy, .bhDuskLavender.opacity(0.55)]
        case .partlyCloudy:
            colors = [.bhRainBlue.opacity(0.6), .bhMistBlue]
        case .cloudyNight:
            colors = [.bhCloudGray, .bhMistBlue.opacity(0.6)]
        case .lightRain:
            colors = [.bhRainBlue, .bhMistBlue.opacity(0.7)]
        case .shower:
            colors = [.bhRainBlue, .bhBlueHourNavy.opacity(0.7)]
        case .fog:
            colors = [.bhMistBlue, .bhCloudGray.opacity(0.7)]
        case .windy:
            colors = [.bhMistBlue.opacity(0.8), .bhRainBlue.opacity(0.5)]
        case .sunset:
            colors = [.bhSunsetPeach, .bhDuskLavender.opacity(0.6)]
        case .moonlight:
            colors = [.bhDuskLavender, .bhBlueHourNavy.opacity(0.5)]
        case .lightThroughClouds:
            colors = [.bhDuskLavender.opacity(0.6), .bhMistBlue]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 비 계열인지 (결과 카드 모션에서 빗줄기를 더할지 판단).
    var isRainy: Bool {
        self == .lightRain || self == .shower
    }
}
