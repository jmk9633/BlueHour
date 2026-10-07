//
//  InterruptedView.swift
//  BlueHour
//
//  전화 등 인터럽션이나 백그라운드 진입으로 녹음이 멈춰 보존됐을 때,
//  복귀한 사용자가 저장할지 다시 말할지 고르는 화면.
//

import SwiftUI

struct InterruptedView: View {
    let viewModel: RecordFlowViewModel

    /// 보존된 녹음이 저장 가능한 최소 길이(3초)를 넘겼는지.
    private var canSave: Bool { viewModel.canSavePreservedRecording }

    private var message: String {
        canSave
            ? "녹음이 잠시 멈췄어요."
            : "녹음이 너무 짧아서 저장할 수 없어요."
    }

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(.bhHeadline)
                    .foregroundStyle(Color.bhTextPrimary)

                Text("지금까지의 녹음은 안전하게 남아 있어요.")
                    .multilineTextAlignment(.center)
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)
                    .opacity(canSave ? 1 : 0)   // 너무 짧을 때는 보존 안내를 비운다
            }

            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                // 3초 미만이면 [저장하기]를 숨기고 [다시 말하기]만 보여준다
                if canSave {
                    Button("저장하기") {
                        Task { await viewModel.continueAfterInterruption() }
                    }
                    .buttonStyle(.bhPrimary)
                }

                Button("다시 말하기") {
                    Task { await viewModel.discardAfterInterruption() }
                }
                .font(canSave ? .bhCaption : .bhBody.weight(.medium))
                .foregroundStyle(canSave ? Color.bhTextSecondary : Color.bhAccent)
            }
        }
        .padding(BHMetrics.screenPadding)
    }
}
