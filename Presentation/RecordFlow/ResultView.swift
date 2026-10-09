//
//  ResultView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct ResultView: View {
    let analysis: SkyAnalysis
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BHMetrics.spacingL) {

                // 하늘 카드
                VStack(alignment: .leading, spacing: BHMetrics.spacingM) {
                    Text(analysis.weatherType.displayName)
                        .font(.bhLabel)
                        .foregroundStyle(Color.bhTextSecondary)

                    Text(analysis.title)
                        .font(.bhTitle)
                        .foregroundStyle(Color.bhTextPrimary)

                    Text(analysis.summary)
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BHMetrics.spacingL)
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
                    .foregroundStyle(Color.bhBlueHourNavy)
                    .padding(.horizontal, BHMetrics.spacingM)
                    .padding(.vertical, BHMetrics.spacingS)
                    .background(
                        Capsule().fill(Color.bhMistBlue.opacity(0.5))
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
    @State private var animate = false

    var body: some View {
        ZStack {
            weatherType.cardGradient
            if !reduceMotion {
                motionLayer
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
