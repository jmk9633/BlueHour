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
}
