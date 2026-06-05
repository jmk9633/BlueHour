//
//  AnalysisView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct AnalysisView: View {
    let state: RecordFlowState

    @State private var breathe = false

    private var lines: (String, String) {
        switch state {
        case .transcribing:
            return ("당신의 말을 옮기고 있어요.", "잠시만 기다려 주세요.")
        default:
            return ("오늘의 하늘을 읽고 있어요.", "당신의 말을\n마음의 날씨로 바꾸는 중이에요.")
        }
    }

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            Circle()
                .fill(Color.bhDuskLavender.opacity(0.4))
                .frame(width: 120, height: 120)
                .scaleEffect(breathe ? 1.15 : 0.9)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: breathe
                )

            VStack(spacing: BHMetrics.spacingS) {
                Text(lines.0)
                Text(lines.1)
            }
            .multilineTextAlignment(.center)
            .font(.bhCaption)
            .foregroundStyle(Color.bhTextSecondary)

            Spacer()
        }
        .padding(BHMetrics.screenPadding)
        .onAppear { breathe = true }
    }
}
