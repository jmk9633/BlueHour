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
                .background(skyGradient)
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

                // 내일의 작은 문장
                sectionView(title: "내일의 작은 문장", body: analysis.tomorrowSentence)

                Spacer(minLength: BHMetrics.spacingL)

                Button("오늘은 여기까지") { onClose() }
                    .buttonStyle(.bhPrimary)
            }
            .padding(BHMetrics.screenPadding)
        }
    }

    private var skyGradient: LinearGradient {
        LinearGradient(
            colors: [Color.bhMistBlue, Color.bhDuskLavender.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
