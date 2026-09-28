//
//  TodayView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct TodayView: View {
    let viewModel: RecordFlowViewModel
    /// 오늘의 하늘 카드를 눌렀을 때(상세 시트 열기). 기록이 없으면 사용하지 않는다.
    var onTapSky: () -> Void = {}

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            Text("오늘의 블루아워")
                .font(.bhHeadline)
                .foregroundStyle(Color.bhTextPrimary)

            if let entry = viewModel.existingEntry {
                // 이미 기록이 있으면 오늘의 하늘을 보여준다 (하루 1개 정책: 새 녹음 버튼은 감춘다)
                skyCard(for: entry)
                Spacer()
            } else {
                // 기록이 없으면 빈 하늘 안내와 단일 버튼만 보여준다
                VStack(spacing: BHMetrics.spacingM) {
                    Text("아직 오늘의 하늘이\n비어 있어요.")
                        .multilineTextAlignment(.center)
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextPrimary)

                    Text("떠오르는 만큼만\n60초 안에 말해보세요.")
                        .multilineTextAlignment(.center)
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                }

                Spacer()

                Button("오늘 말하기") {
                    Task { await viewModel.startRecording() }
                }
                .buttonStyle(.bhPrimary)
            }
        }
        .padding(BHMetrics.screenPadding)
    }

    // MARK: - 오늘의 하늘 카드

    @ViewBuilder
    private func skyCard(for entry: DiaryEntry) -> some View {
        Button(action: onTapSky) {
            VStack(alignment: .leading, spacing: BHMetrics.spacingM) {
                if let analysis = entry.analysis {
                    // 분석이 끝난 하늘
                    Text(analysis.weatherType.displayName)
                        .font(.bhLabel)
                        .foregroundStyle(Color.bhTextSecondary)

                    Text(analysis.title)
                        .font(.bhTitle)
                        .foregroundStyle(Color.bhTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(analysis.summary)
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // 아직 그려지지 않은 하늘 (표시만; 자동 분석은 다음 단계)
                    Text("아직 그려지지 않은 하늘")
                        .font(.bhLabel)
                        .foregroundStyle(Color.bhTextSecondary)

                    Text("오늘의 이야기는 잘 담겼어요.")
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("하늘은 잠시 뒤에 그려질 거예요.")
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BHMetrics.spacingL)
            .background(
                RoundedRectangle(cornerRadius: BHMetrics.cornerL, style: .continuous)
                    .fill(Color.bhMistBlue.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}
