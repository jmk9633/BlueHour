//
//  RecordingView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct RecordingView: View {
    let viewModel: RecordFlowViewModel

    private var timeText: String {
        let elapsed = Int(viewModel.elapsedTime)
        let total = Int(viewModel.maxDuration)
        return String(format: "%02d:%02d / %02d:%02d",
                      elapsed / 60, elapsed % 60,
                      total / 60, total % 60)
    }

    var body: some View {
        VStack(spacing: BHMetrics.spacingXL) {
            Spacer()

            Text(timeText)
                .font(.bhTimer)
                .foregroundStyle(Color.bhTextPrimary)
                .contentTransition(.numericText())

            VStack(spacing: BHMetrics.spacingS) {
                Text("잘 정리해서 말하지 않아도 괜찮아요.")
                Text("멈칫한 순간도 오늘의 일부예요.")
            }
            .multilineTextAlignment(.center)
            .font(.bhCaption)
            .foregroundStyle(Color.bhTextSecondary)

            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Button("저장하기") {
                    Task { await viewModel.stopRecording() }
                }
                .buttonStyle(.bhPrimary)

                Button("다시 말하기") {
                    Task { await viewModel.restart() }
                }
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
            }
        }
        .padding(BHMetrics.screenPadding)
    }
}
