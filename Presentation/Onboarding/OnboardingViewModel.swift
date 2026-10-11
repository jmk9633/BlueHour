//
//  OnboardingViewModel.swift
//  BlueHour
//
//  첫 실행 안내(F-SRJTXF)의 단계 이동과 완료 기록을 담당한다.
//  - 단계: ① 앱 소개 → ② 음성 저장 방식 → ③ AI 미지원 안내(기기 미지원일 때만)
//  - '목소리 남기기'를 미리 선택(keepVoice = true)하고, 완료 시 그 값으로 saveOriginalAudio를 저장한다.
//  - 완료 시에만 hasCompletedOnboarding을 기록하므로, 도중에 앱을 끄면 다음 실행 때 처음부터 다시 보인다.
//

import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {

    /// 첫 실행 안내의 단계.
    enum Step {
        case intro        // ① 앱 소개 + 무료 30개
        case audioChoice  // ② 음성 저장 방식 선택
        case aiNotice     // ③ AI 미지원 기기 안내 (deviceNotEligible일 때만)
    }

    // MARK: - 화면이 바라보는 상태

    private(set) var step: Step = .intro

    /// ② 음성 저장 방식. true면 '목소리 남기기'. F-SRJTXF 기획대로 미리 선택해 둔다.
    var keepVoice: Bool = true

    /// 이 기기가 AI를 원천적으로 지원하지 않는지(deviceNotEligible). true일 때만 ③ 단계를 보여준다.
    var deviceNotEligible: Bool = false

    // MARK: - 의존성

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 단계 판단

    /// 지금 단계가 마지막 단계인지. 마지막이면 버튼이 [시작하기]가 된다.
    var isLastStep: Bool {
        switch step {
        case .intro:
            return false
        case .audioChoice:
            // 기기 미지원일 때만 뒤에 ③이 붙으므로, 지원 기기면 ②가 마지막이다.
            return !deviceNotEligible
        case .aiNotice:
            return true
        }
    }

    // MARK: - 단계 이동

    /// 마지막이 아닐 때 다음 단계로 넘어간다. (마지막 단계에서는 호출하지 않는다 — complete()를 쓴다.)
    func advance() {
        switch step {
        case .intro:
            step = .audioChoice
        case .audioChoice:
            // isLastStep이 false인 경우에만 여기 도달하므로 deviceNotEligible == true.
            step = .aiNotice
        case .aiNotice:
            break
        }
    }

    // MARK: - 완료 기록

    /// 마지막 단계에서 호출. 음성 저장 방식과 첫 실행 완료 여부를 저장한다.
    func complete() {
        defaults.set(keepVoice, forKey: AppSettings.Keys.saveOriginalAudio)
        defaults.set(true, forKey: AppSettings.Keys.hasCompletedOnboarding)
    }
}
