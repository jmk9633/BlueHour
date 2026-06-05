//
//  BlueHourMetrics.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

/// 여백, 모서리 둥글기 등 레이아웃 수치를 한곳에 모은다.
enum BHMetrics {

    // MARK: - 간격 (8pt 그리드 기반)
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 40
    static let spacingXXL: CGFloat = 64

    // MARK: - 모서리 둥글기
    static let cornerS: CGFloat = 12
    static let cornerM: CGFloat = 20
    static let cornerL: CGFloat = 28      // 하늘 카드처럼 큰 카드용

    // MARK: - 화면 가장자리 기본 여백
    static let screenPadding: CGFloat = 24
}
