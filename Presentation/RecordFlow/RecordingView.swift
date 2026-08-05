//
//  RecordingView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct RecordingView: View {
    let viewModel: RecordFlowViewModel

    @State private var showCancelConfirmation = false

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
                if viewModel.isPaused {
                    Text("잠시 멈췄어요.")
                    Text("준비되면 이어서 말해요.")
                } else {
                    Text("잘 정리해서 말하지 않아도 괜찮아요.")
                    Text("멈칫한 순간도 오늘의 일부예요.")
                }
            }
            .multilineTextAlignment(.center)
            .font(.bhCaption)
            .foregroundStyle(Color.bhTextSecondary)

            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Button(viewModel.isPaused ? "이어서 말하기" : "잠시 멈춤") {
                    Task {
                        if viewModel.isPaused {
                            await viewModel.resumeRecording()
                        } else {
                            await viewModel.pauseRecording()
                        }
                    }
                }
                .font(.bhBody.weight(.medium))
                .foregroundStyle(Color.bhAccent)

                Button("저장하기") {
                    Task { await viewModel.stopRecording() }
                }
                .buttonStyle(.bhPrimary)

                Button("취소") {
                    showCancelConfirmation = true
                }
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
            }
        }
        .padding(BHMetrics.screenPadding)
        .alert("취소하시겠습니까?", isPresented: $showCancelConfirmation) {
            Button("계속 녹음", role: .cancel) {}
            Button("취소하기", role: .destructive) {
                Task { await viewModel.restart() }
            }
        } message: {
            Text("지금까지 녹음한 내용이 사라져요.")
        }
    }
}
