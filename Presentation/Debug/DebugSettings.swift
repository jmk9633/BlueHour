//
//  DebugSettings.swift
//  BlueHour
//
//  출시 전 테스트용 개발자 도구의 '강제 설정' 상태.
//  DEBUG 빌드에만 포함되며, Release에는 들어가지 않는다.
//  강제 설정(AI 상태·AI 응답·음성 인식·시각 변경)은 "debug." 접두 키로 UserDefaults에 저장해
//  앱을 다시 켜도 유지된다.
//

#if DEBUG
import Foundation
import Observation

@MainActor
@Observable
final class DebugSettings {

    static let shared = DebugSettings()

    // MARK: - 강제 모드 정의

    /// AI 사용 가능 상태 강제. (도구 #4)
    enum AIState: String, CaseIterable {
        case follow                       // 실제 따름
        case available                    // 사용 가능
        case deviceNotEligible            // 하드웨어 미지원
        case appleIntelligenceNotEnabled  // Apple Intelligence 꺼짐
        case modelNotReady                // 모델 준비 중

        var label: String {
            switch self {
            case .follow: return "실제 따름"
            case .available: return "사용 가능"
            case .deviceNotEligible: return "deviceNotEligible"
            case .appleIntelligenceNotEnabled: return "appleIntelligenceNotEnabled"
            case .modelNotReady: return "modelNotReady"
            }
        }
    }

    /// AI 응답 강제. (도구 #5) 금지어는 SkyExpressionPolicy가 잡아내는 임상 표현을 넣는다.
    enum AIResponse: String, CaseIterable {
        case follow         // 실제 따름
        case riskyThenClean // 1차 금지어 포함, 재생성은 정상
        case riskyBoth      // 1차·재생성 모두 금지어
        case error          // 분석 오류

        var label: String {
            switch self {
            case .follow: return "실제 따름"
            case .riskyThenClean: return "금지어→재생성 정상"
            case .riskyBoth: return "금지어(재생성도)"
            case .error: return "분석 오류"
            }
        }
    }

    /// 음성 인식 강제. (도구 #6)
    enum SpeechMode: String, CaseIterable {
        case follow   // 실제 따름
        case fail     // 실패
        case timeout  // 8초 타임아웃

        var label: String {
            switch self {
            case .follow: return "실제 따름"
            case .fail: return "실패"
            case .timeout: return "8초 타임아웃"
            }
        }
    }

    // MARK: - 저장 키 ("debug." 접두)

    private enum Keys {
        static let aiState = "debug.aiState"
        static let aiResponse = "debug.aiResponse"
        static let speechMode = "debug.speechMode"
        static let clockOffset = "debug.clockOffset"      // TimeInterval
        static let clockEnabled = "debug.clockEnabled"    // Bool
    }

    private let defaults: UserDefaults

    // MARK: - 상태 (변경 즉시 저장 + 시계 반영)

    var aiState: AIState {
        didSet { defaults.set(aiState.rawValue, forKey: Keys.aiState) }
    }
    var aiResponse: AIResponse {
        didSet { defaults.set(aiResponse.rawValue, forKey: Keys.aiResponse) }
    }
    var speechMode: SpeechMode {
        didSet { defaults.set(speechMode.rawValue, forKey: Keys.speechMode) }
    }

    /// 시각 오버라이드 오프셋(초). nil이면 실제 시각.
    private(set) var clockOffset: TimeInterval?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.aiState = AIState(rawValue: defaults.string(forKey: Keys.aiState) ?? "") ?? .follow
        self.aiResponse = AIResponse(rawValue: defaults.string(forKey: Keys.aiResponse) ?? "") ?? .follow
        self.speechMode = SpeechMode(rawValue: defaults.string(forKey: Keys.speechMode) ?? "") ?? .follow
        if defaults.bool(forKey: Keys.clockEnabled) {
            self.clockOffset = defaults.double(forKey: Keys.clockOffset)
        } else {
            self.clockOffset = nil
        }
    }

    // MARK: - 시계

    /// 공용 시계가 현재 강제 설정을 따르도록 반영한다. 앱 시작 시 1회 호출.
    func applyClock() {
        if let offset = clockOffset {
            BlueHourClock.now = { Date().addingTimeInterval(offset) }
        } else {
            BlueHourClock.now = { Date() }
        }
    }

    /// 지정한 시각으로 오버라이드(현재 실제 시각과의 차이를 오프셋으로 저장해 시간이 계속 흐르게 한다).
    func setClock(to target: Date) {
        let offset = target.timeIntervalSince(Date())
        clockOffset = offset
        defaults.set(offset, forKey: Keys.clockOffset)
        defaults.set(true, forKey: Keys.clockEnabled)
        applyClock()
    }

    /// 실제 시각으로 되돌린다.
    func clearClock() {
        clockOffset = nil
        defaults.set(false, forKey: Keys.clockEnabled)
        defaults.removeObject(forKey: Keys.clockOffset)
        applyClock()
    }

    /// 현재(오버라이드 반영) 시각.
    var effectiveNow: Date { BlueHourClock.now() }

    // MARK: - 강제 중 여부 / 모두 되돌리기

    /// 강제 설정이 하나라도 켜져 있는지.
    var isAnyForcingActive: Bool {
        aiState != .follow || aiResponse != .follow || speechMode != .follow || clockOffset != nil
    }

    /// 강제 설정을 모두 '실제'로 되돌린다.
    func resetAllForcing() {
        aiState = .follow
        aiResponse = .follow
        speechMode = .follow
        clearClock()
    }
}
#endif
