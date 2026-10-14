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

    /// 모델이 돌려준 weatherType 문자열을 안전하게 변환한다.
    /// 목록에 없는 값이면 구름 조금(partlyCloudy)으로 대체한다. (F-MEASPV / PL-XNEFLR)
    init(fromModelRawValue raw: String) {
        self = SkyWeatherType(rawValue: raw) ?? .partlyCloudy
    }

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
