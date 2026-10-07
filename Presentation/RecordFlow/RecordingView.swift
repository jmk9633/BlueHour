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
    @State private var showTooShortNotice = false
    /// 취소 확인 알림을 띄우며 자동으로 일시중지했는지 (계속 말하기 시 되돌리기 위함)
    @State private var didAutoPause = false

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
                    // 3초 미만이면 저장하지 않고 조금 더 말하도록 안내 (녹음은 계속 유지)
                    Task {
                        let saved = await viewModel.requestSave()
                        if !saved { showTooShortNotice = true }
                    }
                }
                .buttonStyle(.bhPrimary)

                Button("취소") {
                    // 확인하는 동안에는 녹음을 멈춰 둔다
                    if !viewModel.isPaused {
                        didAutoPause = true
                        Task { await viewModel.pauseRecording() }
                    }
                    showCancelConfirmation = true
                }
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
            }
        }
        .padding(BHMetrics.screenPadding)
        .alert("녹음을 그만둘까요?", isPresented: $showCancelConfirmation) {
            Button("계속 말하기", role: .cancel) {
                // 자동으로 멈춰 두었다면 이어서 녹음
                if didAutoPause {
                    didAutoPause = false
                    Task { await viewModel.resumeRecording() }
                }
            }
            Button("그만두기", role: .destructive) {
                didAutoPause = false
                Task { await viewModel.restart() }
            }
        } message: {
            Text("지금까지 말한 내용은 저장되지 않아요.")
        }
        .alert("조금만 더 말해볼까요?", isPresented: $showTooShortNotice) {
            Button("이어서 말하기", role: .cancel) {}
        } message: {
            Text("3초 이상 말해야 하늘로 담을 수 있어요.")
        }
    }
}
