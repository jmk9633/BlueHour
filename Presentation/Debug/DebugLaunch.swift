//
//  DebugLaunch.swift
//  BlueHour
//
//  DEBUG 전용: 앱 시작 시 실행 인자로 개발자 도구와 같은 상태를 만든다. (프롬프트 C 자동화 대비)
//  지원 인자:
//    -debugReset
//    -debugFreeCount <n>
//    -debugSeed weather10|month|undrawn|voice   (여러 번 가능)
//    -debugAIState follow|available|deviceNotEligible|appleIntelligenceNotEnabled|modelNotReady
//    -debugSkipOnboarding
//    -debugClock <ISO8601>
//

#if DEBUG
import Foundation
import UserNotifications

/// 실행 인자를 해석한 결과(순수 값). 파싱만 담당해 테스트 가능하게 분리한다.
struct DebugLaunchArguments: Equatable {
    var reset = false
    var freeCount: Int?
    var seeds: [DebugSeedKind] = []
    var aiState: DebugSettings.AIState?
    var skipOnboarding = false
    var clock: Date?

    /// 아무 디버그 인자도 없으면 비어 있는지.
    var isEmpty: Bool {
        !reset && freeCount == nil && seeds.isEmpty && aiState == nil && !skipOnboarding && clock == nil
    }

    static func parse(_ args: [String]) -> DebugLaunchArguments {
        var result = DebugLaunchArguments()
        let iso = ISO8601DateFormatter()
        var index = 0
        while index < args.count {
            let token = args[index]
            func nextValue() -> String? {
                guard index + 1 < args.count else { return nil }
                index += 1
                return args[index]
            }
            switch token {
            case "-debugReset":
                result.reset = true
            case "-debugSkipOnboarding":
                result.skipOnboarding = true
            case "-debugFreeCount":
                if let value = nextValue(), let n = Int(value) {
                    result.freeCount = n
                }
            case "-debugSeed":
                if let value = nextValue(), let kind = DebugSeedKind(rawValue: value) {
                    result.seeds.append(kind)
                }
            case "-debugAIState":
                if let value = nextValue(), let state = DebugSettings.AIState(rawValue: value) {
                    result.aiState = state
                }
            case "-debugClock":
                if let value = nextValue(), let date = iso.date(from: value) {
                    result.clock = date
                }
            default:
                break
            }
            index += 1
        }
        return result
    }
}

@MainActor
enum DebugLaunch {

    /// DIContainer 생성 전에 적용할 것들(기본값·키체인·시계·강제 상태·온보딩 건너뛰기).
    /// - Returns: 해석된 인자(late 단계에서 seed·reset 데이터 작업에 재사용).
    @discardableResult
    static func applyEarly(
        _ args: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) -> DebugLaunchArguments {
        let parsed = DebugLaunchArguments.parse(args)
        guard !parsed.isEmpty else {
            DebugSettings.shared.applyClock()  // 저장된 오버라이드 반영
            return parsed
        }

        if parsed.reset {
            // UserDefaults·키체인을 비운다(데이터·음성·알림은 late에서).
            if let bundleID = Bundle.main.bundleIdentifier {
                defaults.removePersistentDomain(forName: bundleID)
            }
            KeychainFreeSkyCountStore().debugDeleteStored()
        }

        if let n = parsed.freeCount {
            // DIContainer가 카운터를 만들 때 store.load()로 읽어가도록 미리 저장.
            KeychainFreeSkyCountStore().save(n)
        }

        if parsed.skipOnboarding {
            defaults.set(true, forKey: AppSettings.Keys.hasCompletedOnboarding)
        }

        if let state = parsed.aiState {
            DebugSettings.shared.aiState = state
        }

        if let clock = parsed.clock {
            DebugSettings.shared.setClock(to: clock)
        }
        // 저장된(또는 방금 설정한) 시계 오버라이드를 공용 시계에 반영.
        DebugSettings.shared.applyClock()

        return parsed
    }

    /// DIContainer.setup 이후 적용할 것들(데이터 전체 초기화·샘플 주입).
    static func applyLate(_ parsed: DebugLaunchArguments, di: DIContainer) async {
        guard !parsed.isEmpty else { return }

        if parsed.reset {
            try? await di.diaryRepository.deleteAll()
            try? await di.audioService.deleteAllRecordings()
            UNUserNotificationCenterCleaner.removeAllPending()
        }

        for seed in parsed.seeds {
            _ = try? await DebugSampleBuilder.seed(seed, into: di)
        }
    }
}

/// 알림 전체 취소를 한 곳에서. (개발자 도구·실행 인자 공용)
enum UNUserNotificationCenterCleaner {
    static func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
#endif
