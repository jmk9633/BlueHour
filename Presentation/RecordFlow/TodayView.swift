//
//  TodayView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct TodayView: View {
    let viewModel: RecordFlowViewModel

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            Text("오늘의 블루아워")
                .font(.bhHeadline)
                .foregroundStyle(Color.bhTextPrimary)

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
        .padding(BHMetrics.screenPadding)
    }
}
