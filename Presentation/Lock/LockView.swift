//
//  LockView.swift
//  BlueHour
//
//  Face ID 잠금 화면(F-TNEYMY). 블루아워 배경색으로 내용을 완전히 가리고,
//  인증 실패 시 '다시 시도' 버튼으로 재인증할 수 있다.
//

import SwiftUI

struct LockView: View {
    /// 인증 진행 중 여부. 진행 중이면 버튼 대신 진행 표시를 보여준다.
    let isAuthenticating: Bool
    /// '다시 시도' 동작.
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            // 내용을 가리는 덮개
            Color.bhBackground.ignoresSafeArea()

            VStack(spacing: BHMetrics.spacingL) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.bhAccent)

                Text("오늘의 기록은 나만 볼 수 있어요.")
                    .font(.bhBody)
                    .foregroundStyle(Color.bhTextPrimary)
                    .multilineTextAlignment(.center)

                if isAuthenticating {
                    ProgressView()
                        .padding(.top, BHMetrics.spacingS)
                } else {
                    Button("다시 시도", action: onRetry)
                        .buttonStyle(.bhPrimary)
                        .padding(.horizontal, BHMetrics.spacingXXL)
                        .padding(.top, BHMetrics.spacingS)
                }
            }
            .padding(.horizontal, BHMetrics.screenPadding)
        }
    }
}
