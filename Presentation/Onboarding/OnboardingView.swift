//
//  OnboardingView.swift
//  BlueHour
//
//  첫 실행 안내(F-SRJTXF). 한 화면에 한 단계씩 보여주며, 문구는 기획 display 그대로 사용한다.
//  ③ AI 미지원 안내는 기기가 원천적으로 미지원(deviceNotEligible)일 때만 보여준다.
//

import SwiftUI

struct OnboardingView: View {

    /// 기기 AI 지원 여부를 확인하기 위한 분석 서비스.
    let analysisService: SkyAnalysisServiceProtocol
    /// 첫 실행 안내를 끝까지 마쳤을 때 호출. (루트 화면이 오늘 탭으로 전환)
    let onComplete: () -> Void

    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            Color.bhBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: BHMetrics.spacingXL)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, BHMetrics.screenPadding)
                    .animation(.easeInOut(duration: 0.35), value: viewModel.step)

                primaryButton
                    .padding(.horizontal, BHMetrics.screenPadding)
                    .padding(.bottom, BHMetrics.spacingXL)
            }
        }
        .task {
            // 기기가 AI를 원천적으로 지원하지 않을 때만 ③ 단계를 노출한다.
            viewModel.deviceNotEligible = !(await analysisService.isDeviceEligible())
        }
    }

    // MARK: - 단계별 본문

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .intro:
            introStep
        case .audioChoice:
            audioChoiceStep
        case .aiNotice:
            aiNoticeStep
        }
    }

    // ① 앱 소개 + 무료 30개 안내
    private var introStep: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Text("잠들기 전 60초, 오늘의 마음이 하늘이 됩니다.")
                .font(.bhTitle)
                .foregroundStyle(Color.bhTextPrimary)
                .multilineTextAlignment(.center)

            Text("길게 쓰지 않아도 괜찮아요. 오늘을 말하면 블루아워가 마음의 날씨로 남겨드려요.")
                .font(.bhBody)
                .foregroundStyle(Color.bhTextPrimary)
                .multilineTextAlignment(.center)

            Text("하늘 30개까지는 무료로 담을 수 있어요. 그다음엔 한 번 구매로 계속 함께할 수 있어요.")
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, BHMetrics.spacingS)
        }
    }

    // ② 음성 저장 방식 선택
    private var audioChoiceStep: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Text("목소리도 함께 남길까요?")
                .font(.bhTitle)
                .foregroundStyle(Color.bhTextPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: BHMetrics.spacingM) {
                choiceRow(
                    title: "목소리 남기기",
                    detail: "그날의 목소리를 다시 들을 수 있어요.",
                    selected: viewModel.keepVoice
                ) {
                    viewModel.keepVoice = true
                }

                choiceRow(
                    title: "글과 하늘만 남기기",
                    detail: "말한 내용은 글로 옮기고 목소리는 지워요.",
                    selected: !viewModel.keepVoice
                ) {
                    viewModel.keepVoice = false
                }
            }

            Text("나 탭에서 언제든 바꿀 수 있어요.")
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, BHMetrics.spacingS)
        }
    }

    // ③ AI 미지원 기기 안내 (deviceNotEligible일 때만)
    private var aiNoticeStep: some View {
        VStack(spacing: BHMetrics.spacingL) {
            Text("이 기기에서는 하늘 없이 말과 글만 남아요. iPhone 15 Pro 이상에서는 하늘이 함께 그려져요.")
                .font(.bhBody)
                .foregroundStyle(Color.bhTextPrimary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 선택지 행

    private func choiceRow(
        title: String,
        detail: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: BHMetrics.spacingM) {
                VStack(alignment: .leading, spacing: BHMetrics.spacingXS) {
                    Text(title)
                        .font(.bhBody.weight(.medium))
                        .foregroundStyle(Color.bhTextPrimary)
                    Text(detail)
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.bhAccent : Color.bhTextSecondary)
            }
            .padding(BHMetrics.spacingM)
            .background(
                RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous)
                    .fill(Color.bhSurface)
            )
            // 선택된 행은 강조 테두리로 구분한다. (배경은 두 행 모두 bhSurface 공통)
            .overlay(
                RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous)
                    .strokeBorder(Color.bhAccent, lineWidth: selected ? 1.5 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 하단 버튼

    private var primaryButton: some View {
        Button(viewModel.isLastStep ? "시작하기" : "다음") {
            if viewModel.isLastStep {
                viewModel.complete()
                onComplete()
            } else {
                viewModel.advance()
            }
        }
        .buttonStyle(.bhPrimary)
    }
}
