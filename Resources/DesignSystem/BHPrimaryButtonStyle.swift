//
//  BHPrimaryButtonStyle.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

/// 블루아워의 주요 버튼 스타일. "오늘 말하기" 같은 핵심 액션에 사용.
struct BHPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bhBody.weight(.medium))
            .foregroundStyle(Color.bhWarmIvory)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BHMetrics.spacingM)
            .background(Color.bhAccent)
            .clipShape(RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous))
            // 눌렀을 때 살짝 작아지고 흐려지는 부드러운 반응
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BHPrimaryButtonStyle {
    /// 사용: Button("오늘 말하기") { ... }.buttonStyle(.bhPrimary)
    static var bhPrimary: BHPrimaryButtonStyle { BHPrimaryButtonStyle() }
}
