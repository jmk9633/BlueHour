//
//  ReminderPromptView.swift
//  BlueHour
//
//  첫 기록 결과 화면에서 [오늘은 여기까지] 위에 한 번 보여주는 밤 리마인더 제안.
//  문구는 PL-OZYYZI / F-LDUDEX display 그대로 사용한다.
//

import SwiftUI

struct ReminderPromptView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: BHMetrics.spacingM) {
            Text("내일 밤에도 하늘을 남길 수 있게 알려드릴까요?")
                .font(.bhBody)
                .foregroundStyle(Color.bhTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: BHMetrics.spacingM) {
                Button("괜찮아요") { onDecline() }
                    .foregroundStyle(Color.bhTextSecondary)

                Button("알려주세요") { onAccept() }
                    .foregroundStyle(Color.bhAccent)
            }
            .font(.bhBody)
        }
        .frame(maxWidth: .infinity)
        .padding(BHMetrics.spacingL)
        .background(
            RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous)
                .fill(Color.bhSurface)
        )
    }
}
