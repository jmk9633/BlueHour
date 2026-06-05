//
//  FailureView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct FailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Spacer()
            Text(message)
                .multilineTextAlignment(.center)
                .font(.bhBody)
                .foregroundStyle(Color.bhTextPrimary)
            Spacer()
            Button("다시 해보기") { onRetry() }
                .buttonStyle(.bhPrimary)
        }
        .padding(BHMetrics.screenPadding)
    }
}
