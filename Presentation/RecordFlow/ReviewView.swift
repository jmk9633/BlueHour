//
//  ReviewView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct ReviewView: View {
    @Bindable var viewModel: RecordFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BHMetrics.spacingL) {
            Text("오늘 말한 내용이에요")
                .font(.bhHeadline)
                .foregroundStyle(Color.bhTextPrimary)

            Text("어색한 부분이 있다면\n가볍게 다듬어도 좋아요.")
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)

            TextEditor(text: $viewModel.editableText)
                .font(.bhBody)
                .foregroundStyle(Color.bhTextPrimary)
                .scrollContentBackground(.hidden)
                .padding(BHMetrics.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous)
                        .fill(Color.bhMistBlue.opacity(0.3))
                )
                .frame(maxHeight: 240)

            Spacer()

            Button("오늘의 하늘 보기") {
                Task { await viewModel.confirmAndAnalyze() }
            }
            .buttonStyle(.bhPrimary)
        }
        .padding(BHMetrics.screenPadding)
    }
}
