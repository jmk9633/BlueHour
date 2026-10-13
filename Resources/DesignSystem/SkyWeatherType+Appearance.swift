//
//  SkyWeatherType+Appearance.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    /// 결과 카드 그라데이션을 이루는 날씨별 두 색 (팔레트 색 + 불투명도).
    /// 카드 안쪽 Warm Ivory 바탕 위에 그려지므로, 불투명도 색은 Ivory에 합성된다.
    var gradientStops: [(color: Color, opacity: Double)] {
        switch self {
        case .clearNight:         return [(.bhBlueHourNavy, 1.0), (.bhDuskLavender, 0.55)]
        case .partlyCloudy:       return [(.bhRainBlue, 0.6), (.bhMistBlue, 1.0)]
        case .cloudyNight:        return [(.bhCloudGray, 1.0), (.bhMistBlue, 0.6)]
        case .lightRain:          return [(.bhRainBlue, 1.0), (.bhMistBlue, 0.7)]
        case .shower:             return [(.bhRainBlue, 1.0), (.bhBlueHourNavy, 0.7)]
        case .fog:                return [(.bhMistBlue, 1.0), (.bhCloudGray, 0.7)]
        case .windy:              return [(.bhMistBlue, 0.8), (.bhRainBlue, 0.5)]
        case .sunset:             return [(.bhSunsetPeach, 1.0), (.bhDuskLavender, 0.6)]
        case .moonlight:          return [(.bhDuskLavender, 1.0), (.bhBlueHourNavy, 0.5)]
        case .lightThroughClouds: return [(.bhDuskLavender, 0.6), (.bhMistBlue, 1.0)]
        }
    }

    /// 결과 카드 배경에 쓰는 날씨 유형별 그라데이션. 디자인 토큰 색만 조합한다.
    var cardGradient: LinearGradient {
        LinearGradient(
            colors: gradientStops.map { $0.color.opacity($0.opacity) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 카드 위 글자색(제목·요약·라벨). 화면 모드와 관계없이 날씨마다 고정한다. (F-QMDQQQ)
    /// 그라데이션 두 색 모두와 대비가 확보되는 쪽(필요하면 스크림과 함께)으로 정한다.
    var cardTextColor: Color {
        switch self {
        case .clearNight, .shower, .moonlight:
            return .bhWarmIvory
        default:
            return .bhSoftCharcoal
        }
    }

    /// 글자 뒤 보호 스크림. 글자색의 반대 계열 색을 날씨별 최소 불투명도로 깐다.
    /// nil이면 스크림 없이도 두 색 모두에서 대비 4.5:1 이상인 날씨다.
    /// 투명도는 "Ivory 바탕 합성 → 다크 10% 덮개 → 스크림" 순서로 계산한 라이트·다크 공통 최소값.
    var cardScrim: (color: Color, opacity: Double)? {
        switch self {
        case .clearNight:  return (.bhBlueHourNavy, 0.64)
        case .shower:      return (.bhBlueHourNavy, 0.36)
        case .moonlight:   return (.bhBlueHourNavy, 0.53)
        case .lightRain:   return (.bhWarmIvory, 0.23)
        default:           return nil
        }
    }

    /// 비 계열인지 (결과 카드 모션에서 빗줄기를 더할지 판단).
    var isRainy: Bool {
        self == .lightRain || self == .shower
    }
}

// MARK: - 카드 글자 대비 계산 (테스트로 4.5:1 보장)

/// 하늘 카드 글자색의 대비를 검증하기 위한 순수 계산 유틸.
/// 렌더링과 같은 합성 순서(Ivory 바탕 → 그라데이션 → 다크 10% 덮개 → 스크림)를 따른다.
enum SkyCardContrast {

    /// Color의 sRGB 성분(0~1). UIKit이 없으면 검정을 돌려준다.
    static func components(_ color: Color) -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (0, 0, 0)
        #endif
    }

    /// top을 opacity로 bottom 위에 합성한 색.
    static func composite(
        _ top: (r: Double, g: Double, b: Double),
        opacity: Double,
        over bottom: (r: Double, g: Double, b: Double)
    ) -> (r: Double, g: Double, b: Double) {
        (
            top.r * opacity + bottom.r * (1 - opacity),
            top.g * opacity + bottom.g * (1 - opacity),
            top.b * opacity + bottom.b * (1 - opacity)
        )
    }

    static func relativeLuminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    static func ratio(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double)
    ) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

extension SkyWeatherType {

    /// 이 날씨 카드에서 글자색과 그라데이션 두 색 사이 최소 대비.
    /// dark=true면 검정 10% 덮개까지 포함한다. 스크림이 있으면 스크림 적용 후로 계산한다.
    func minCardTextContrast(dark: Bool) -> Double {
        let ivory = SkyCardContrast.components(.bhWarmIvory)
        let text = SkyCardContrast.components(cardTextColor)
        let scrim = cardScrim
        var worst = Double.greatestFiniteMagnitude
        for stop in gradientStops {
            // ① Warm Ivory 바탕 위에 그라데이션 색(불투명도) 합성
            var eff = SkyCardContrast.composite(
                SkyCardContrast.components(stop.color),
                opacity: stop.opacity,
                over: ivory
            )
            // ② 다크면 검정 10% 덮개
            if dark {
                eff = SkyCardContrast.composite((0, 0, 0), opacity: 0.10, over: eff)
            }
            // ③ 스크림
            if let scrim {
                eff = SkyCardContrast.composite(
                    SkyCardContrast.components(scrim.color),
                    opacity: scrim.opacity,
                    over: eff
                )
            }
            worst = min(worst, SkyCardContrast.ratio(text, eff))
        }
        return worst
    }
}
