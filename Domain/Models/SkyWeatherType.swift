//
//  SkyWeatherType.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

enum SkyWeatherType: String, Codable, CaseIterable, Sendable {
    case clearNight
    case partlyCloudy
    case cloudyNight
    case lightRain
    case shower
    case fog
    case windy
    case sunset
    case moonlight
    case lightThroughClouds

    var displayName: String {
        switch self {
        case .clearNight:        return "맑은 밤"
        case .partlyCloudy:      return "구름 조금"
        case .cloudyNight:       return "흐린 밤"
        case .lightRain:         return "얇은 비"
        case .shower:            return "소나기"
        case .fog:               return "안개"
        case .windy:             return "바람 부는 밤"
        case .sunset:            return "노을"
        case .moonlight:         return "고요한 밤하늘"
        case .lightThroughClouds: return "구름 사이 작은 빛"
        }
    }
}
