//
//  UndrawnSkyResultView.swift
//  BlueHour
//
//  AI를 쓸 수 없어 하늘 없이 기록이 저장됐을 때 보여주는 담담한 안내 화면.
//  (F-LLFPXL — '아직 그려지지 않은 하늘') 하늘은 준비되면 자동으로 그려진다.
//  AI를 쓸 수 없는 이유에 따라 안내 문구와 [설정 열기] 노출이 달라진다. (S-MEOLWE / PL-FUVSGO)
//

import SwiftUI

struct UndrawnSkyResultView: View {
    /// AI를 쓸 수 없었던 이유. 상태별 안내 문구를 고른다. nil이면 일반 안내.
    var reason: SkyUnavailableReason?
    /// 30번째 무료 하늘일 때 한 번 보여주는 안내. (PL-OBQXIP)
    var showFreeLimitNotice: Bool = false
    /// 첫 기록일 때 한 번 보여주는 밤 리마인더 제안. (F-LDUDEX)
    var showReminderPrompt: Bool = false
    var onAcceptReminder: () -> Void = {}
    var onDeclineReminder: () -> Void = {}
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Text("오늘의 이야기는 담겼어요.")
                    .font(.bhHeadline)
                    .foregroundStyle(Color.bhTextPrimary)

                Text(Self.guidance(for: reason))
                    .multilineTextAlignment(.center)
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)

                // Apple Intelligence가 꺼져 있을 때만 설정으로 바로 갈 수 있게 한다. (S-MEOLWE)
                if reason == .appleIntelligenceNotEnabled {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhAccent)
                }
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

    /// 이유별 안내 문구. 문구는 기획 display(S-MEOLWE / F-LLFPXL) 그대로 사용한다.
    static func guidance(for reason: SkyUnavailableReason?) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence를 켜면 이 날의 하늘이 그려져요."
        case .modelNotReady:
            return "하늘을 그릴 준비를 하고 있어요. 준비되면 자동으로 그려져요."
        case .deviceNotEligible, .none:
            return "하늘은 준비되면 곧 그려져요."
        }
    }
}
