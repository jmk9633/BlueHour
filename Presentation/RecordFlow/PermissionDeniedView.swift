//
//  PermissionDeniedView.swift
//  BlueHour
//
//  마이크 권한이 거부됐을 때 안내하는 화면.
//  설정으로 보내거나, 녹음 없이 텍스트로 쓰도록 안내한다.
//

import SwiftUI

struct PermissionDeniedView: View {
    let viewModel: RecordFlowViewModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Text("마이크 권한이 필요해요.")
                    .font(.bhHeadline)
                    .foregroundStyle(Color.bhTextPrimary)

                Text("설정에서 허용해 주세요.")
                    .multilineTextAlignment(.center)
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)
            }

            Spacer()

            VStack(spacing: BHMetrics.spacingM) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.bhPrimary)

                Button("텍스트로 쓰기") {
                    Task { await viewModel.beginTextWriting() }
                }
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
            }
        }
        .padding(BHMetrics.screenPadding)
    }
}
