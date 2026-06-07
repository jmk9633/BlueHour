//
//  SkyDetailView.swift
//  BlueHour
//

import SwiftUI

struct SkyDetailView: View {
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss

    private var analysis: SkyAnalysis? { entry.analysis }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BHMetrics.spacingL) {

                Text(dateText)
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)

                if let analysis {
                    Text(analysis.title)
                        .font(.bhHeadline)
                        .foregroundStyle(Color.bhTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(analysis.summary)
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextPrimary)

                    if !analysis.emotionKeywords.isEmpty {
                        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                            Text("감정 키워드")
                                .font(.bhCaption)
                                .foregroundStyle(Color.bhTextSecondary)
                            HStack(spacing: BHMetrics.spacingS) {
                                ForEach(analysis.emotionKeywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.bhCaption)
                                        .padding(.horizontal, BHMetrics.spacingM)
                                        .padding(.vertical, BHMetrics.spacingS)
                                        .background(
                                            Capsule().fill(Color.bhMistBlue.opacity(0.3))
                                        )
                                        .foregroundStyle(Color.bhTextPrimary)
                                }
                            }
                        }
                    }

                    if let theme = analysis.mainTheme {
                        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                            Text("오늘 마음에 남은 것")
                                .font(.bhCaption)
                                .foregroundStyle(Color.bhTextSecondary)
                            Text(theme)
                                .font(.bhBody)
                                .foregroundStyle(Color.bhTextPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                        Text("내일의 작은 문장")
                            .font(.bhCaption)
                            .foregroundStyle(Color.bhTextSecondary)
                        Text(analysis.tomorrowSentence)
                            .font(.bhBody)
                            .foregroundStyle(Color.bhTextPrimary)
                    }

                    if let transcript = entry.transcript {
                        DisclosureGroup {
                            Text(transcript.editedText ?? transcript.originalText)
                                .font(.bhBody)
                                .foregroundStyle(Color.bhTextSecondary)
                                .padding(.top, BHMetrics.spacingS)
                        } label: {
                            Text("그날의 기록")
                                .font(.bhCaption)
                                .foregroundStyle(Color.bhTextSecondary)
                        }
                        .tint(Color.bhTextSecondary)
                    }
                } else {
                    Text("이 날의 하늘은 아직 비어 있어요.")
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BHMetrics.screenPadding)
        }
        .background(Color.bhBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
                    .foregroundStyle(Color.bhTextSecondary)
            }
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: entry.date)
    }
}
