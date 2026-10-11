//
//  UndrawnSkyResultView.swift
//  BlueHour
//
//  AI를 쓸 수 없어 하늘 없이 기록이 저장됐을 때 보여주는 담담한 안내 화면.
//  (F-LLFPXL — '아직 그려지지 않은 하늘') 하늘은 준비되면 자동으로 그려진다.
//

import SwiftUI

struct UndrawnSkyResultView: View {
    /// 30번째 무료 하늘일 때 한 번 보여주는 안내. (PL-OBQXIP)
    var showFreeLimitNotice: Bool = false
    /// 첫 기록일 때 한 번 보여주는 밤 리마인더 제안. (F-LDUDEX)
    var showReminderPrompt: Bool = false
    var onAcceptReminder: () -> Void = {}
    var onDeclineReminder: () -> Void = {}
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Text("오늘의 이야기는 담겼어요.")
                    .font(.bhHeadline)
                    .foregroundStyle(Color.bhTextPrimary)

                Text("하늘은 준비되면\n곧 그려질 거예요.")
                    .multilineTextAlignment(.center)
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)
            }

            Spacer()

            if showFreeLimitNotice {
                Text("무료로 담을 수 있는 하늘을 모두 채웠어요.")
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if showReminderPrompt {
                ReminderPromptView(onAccept: onAcceptReminder, onDecline: onDeclineReminder)
            }

            Button("오늘은 여기까지") { onClose() }
                .buttonStyle(.bhPrimary)
        }
        .padding(BHMetrics.screenPadding)
    }
}
