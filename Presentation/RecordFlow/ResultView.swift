//
//  ResultView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct ResultView: View {
    let analysis: SkyAnalysis
    /// 30번째 무료 하늘일 때 한 번 보여주는 안내. (PL-OBQXIP)
    var showFreeLimitNotice: Bool = false
    /// 첫 기록일 때 한 번 보여주는 밤 리마인더 제안. (F-LDUDEX)
    var showReminderPrompt: Bool = false
    var onAcceptReminder: () -> Void = {}
    var onDeclineReminder: () -> Void = {}
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BHMetrics.spacingL) {

                // 하늘 카드 — 날씨별 글자색은 화면 모드와 무관하게 고정 (F-QMDQQQ)
                VStack(alignment: .leading, spacing: BHMetrics.spacingM) {
                    Text(analysis.weatherType.displayName)
                        .font(.bhLabel)
                        .foregroundStyle(analysis.weatherType.cardTextColor)

                    Text(analysis.title)
                        .font(.bhTitle)
                        .foregroundStyle(analysis.weatherType.cardTextColor)

                    Text(analysis.summary)
                        .font(.bhBody)
                        .foregroundStyle(analysis.weatherType.cardTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BHMetrics.spacingL)
                // 글자 뒤 보호 스크림(필요한 날씨만). 테두리 없이 가장자리가 흐려진다.
                .background(CardTextScrim(weatherType: analysis.weatherType))
                .background(SkyCardBackground(weatherType: analysis.weatherType))
                .clipShape(RoundedRectangle(cornerRadius: BHMetrics.cornerL, style: .continuous))

                // 감정 키워드
                if !analysis.emotionKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                        Text("감정 키워드")
                            .font(.bhLabel)
                            .foregroundStyle(Color.bhTextSecondary)
                        keywordFlow
                    }
                }

                // 오늘 마음에 남은 것
                if let theme = analysis.mainTheme {
                    sectionView(title: "오늘 마음에 남은 것", body: theme)
                }

                // 회복의 신호 (없으면 숨김)
                if let recovery = analysis.recoverySignal {
                    sectionView(title: "회복의 신호", body: recovery)
                }

                // 내일의 작은 문장
                sectionView(title: "내일의 작은 문장", body: analysis.tomorrowSentence)

                Spacer(minLength: BHMetrics.spacingL)

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

    private var keywordFlow: some View {
        // 간단한 가로 래핑 (키워드 칩)
        HStack {
            ForEach(analysis.emotionKeywords, id: \.self) { keyword in
                Text(keyword)
                    .font(.bhLabel)
                    .foregroundStyle(Color.bhTextPrimary)
                    .padding(.horizontal, BHMetrics.spacingM)
                    .padding(.vertical, BHMetrics.spacingS)
                    .background(
                        Capsule().fill(Color.bhSurface)
                    )
            }
        }
    }

    private func sectionView(title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
            Text(title)
                .font(.bhLabel)
                .foregroundStyle(Color.bhTextSecondary)
            Text(text)
                .font(.bhBody)
                .foregroundStyle(Color.bhTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 하늘 카드 배경 (날씨별 그라데이션 + 미세한 모션)

private struct SkyCardBackground: View {
    let weatherType: SkyWeatherType

    // '동작 줄이기'가 켜져 있으면 모션 없이 그라데이션만 보여준다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // 다크 모드에서는 색 조합을 그대로 두고 검정 10% 덮개로 밝기만 낮춘다. (F-QMDQQQ)
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    var body: some View {
        ZStack {
            // 투명도 있는 그라데이션 색이 화면 배경과 섞이지 않도록 Warm Ivory 바탕을 먼저 깐다.
            Color.bhWarmIvory
            weatherType.cardGradient
            if !reduceMotion {
                motionLayer
            }
            if colorScheme == .dark {
                Color.black.opacity(0.10)
            }
        }
    }

    private var motionLayer: some View {
        GeometryReader { geo in
            ZStack {
                // 부드럽게 흐르는 구름 느낌의 블러 타원 2개
                Ellipse()
                    .fill(Color.bhWarmIvory.opacity(0.12))
                    .frame(width: geo.size.width * 0.8, height: geo.size.height * 0.45)
                    .blur(radius: 24)
                    .offset(
                        x: animate ? geo.size.width * 0.18 : -geo.size.width * 0.18,
                        y: -geo.size.height * 0.1
                    )

                Ellipse()
                    .fill(Color.bhMistBlue.opacity(0.18))
                    .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.35)
                    .blur(radius: 20)
                    .offset(
                        x: animate ? -geo.size.width * 0.12 : geo.size.width * 0.12,
                        y: geo.size.height * 0.18
                    )

                // 비 계열이면 은은한 빗줄기를 더한다
                if weatherType.isRainy {
                    rainStreaks(in: geo.size)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func rainStreaks(in size: CGSize) -> some View {
        HStack(spacing: size.width / 10) {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(Color.bhWarmIvory.opacity(0.18))
                    .frame(width: 1.5, height: size.height * 0.22)
                    .offset(y: animate ? size.height * 0.12 : -size.height * 0.12)
                    .animation(
                        .easeInOut(duration: 2.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
        .rotationEffect(.degrees(12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 카드 글자 뒤 보호 스크림 (F-QMDQQQ)

/// 제목·요약·라벨이 놓인 영역 뒤에 깔아 글자 대비를 확보한다.
/// 상자 테두리 없이 가장자리가 흐려지는 형태. 스크림이 없는 날씨면 아무것도 그리지 않는다.
private struct CardTextScrim: View {
    let weatherType: SkyWeatherType

    var body: some View {
        if let scrim = weatherType.cardScrim {
            RoundedRectangle(cornerRadius: BHMetrics.cornerL, style: .continuous)
                .fill(scrim.color.opacity(scrim.opacity))
                .padding(BHMetrics.spacingS)
                .blur(radius: 20)
        }
    }
}
