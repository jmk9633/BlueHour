//
//  PurchaseView.swift
//  BlueHour
//
//  구매 화면(F-MVCMCF). 평생 이용권 가격·혜택을 보여주고 한 번 구매한다.
//  문구는 기획 display 그대로 쓰며, 카운트다운이나 할인 강조를 두지 않는다.
//

import SwiftUI

struct PurchaseView: View {
    @Environment(\.dismiss) private var dismiss

    let controller: PurchaseController
    /// AI 미지원 안내 판별용(5단계 isDeviceEligible 결과를 뒤집어 사용).
    let analysisService: SkyAnalysisServiceProtocol
    /// 구매(또는 복원으로 해제)가 완료됐을 때 호출. 원래 하려던 동작으로 이어간다.
    let onPurchased: () -> Void

    @State private var deviceNotEligible = false
    @State private var isWorking = false
    @State private var restoreMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: BHMetrics.spacingL) {
                Spacer(minLength: BHMetrics.spacingXL)

                Text("앞으로의 밤도\n하늘로 남겨볼까요?")
                    .font(.bhTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.bhTextPrimary)

                Text("한 번 구매로 평생 이용")
                    .font(.bhBody)
                    .foregroundStyle(Color.bhTextSecondary)

                if let price = controller.displayPrice {
                    Text(price)
                        .font(.bhHeadline)
                        .foregroundStyle(Color.bhTextPrimary)
                }

                Text("이미 만든 하늘은 구매와 관계없이 계속 볼 수 있어요.")
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: BHMetrics.spacingL)

                if controller.loadFailed {
                    Text("잠시 후 다시 시도해 주세요.")
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                        .multilineTextAlignment(.center)
                }

                if controller.purchasePending {
                    Text("결제가 승인되면 자동으로 이용할 수 있어요.")
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                        .multilineTextAlignment(.center)
                }

                // AI 미지원 기기 안내 — 구매 버튼 위에 표시
                if deviceNotEligible {
                    Text("이 기기에서는 하늘이 그려지지 않아요. iPhone 15 Pro 이상에서는 하늘이 함께 그려져요.")
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                        .multilineTextAlignment(.center)
                }

                Button("평생 이용하기") {
                    Task {
                        isWorking = true
                        let ok = await controller.purchase()
                        isWorking = false
                        if ok {
                            onPurchased()
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.bhPrimary)
                .disabled(isWorking || controller.displayPrice == nil)

                Button("구매 복원") {
                    Task {
                        isWorking = true
                        let message = await controller.restore()
                        isWorking = false
                        restoreMessage = message
                        if controller.isUnlocked {
                            onPurchased()
                            dismiss()
                        }
                    }
                }
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)

                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: BHMetrics.spacingL) {
                    Link("이용약관", destination: LegalLinks.termsOfService)
                    Link("개인정보처리방침", destination: LegalLinks.privacyPolicy)
                }
                .font(.bhLabel)
                .foregroundStyle(Color.bhTextSecondary)

                Spacer(minLength: BHMetrics.spacingXL)
            }
            .frame(maxWidth: .infinity)
            .padding(BHMetrics.screenPadding)
        }
        .background(Color.bhBackground.ignoresSafeArea())
        .task {
            deviceNotEligible = !(await analysisService.isDeviceEligible())
            await controller.loadProduct()
        }
    }
}
