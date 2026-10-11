//
//  RootView.swift
//  BlueHour
//
//  앱의 최상위 코디네이터. 첫 실행 안내 → (완료 후) 메인 탭을 보여주고,
//  그 위에 Face ID 잠금/앱 전환기 덮개를 오버레이한다.
//
//  오버레이 방식(ZStack)으로 MainTabView를 트리에서 제거하지 않으므로,
//  RecordFlowView의 scenePhase 기반 2단계 인터럽션 처리(백그라운드 진입 시 녹음 정지·보존)가
//  잠금과 독립적으로 그대로 동작한다.
//
//  덮개/잠금 규칙:
//   - useFaceIDLock && scenePhase != .active  → 내용을 가리는 덮개 (앱 전환기 미리보기 보호)
//   - lock.isLocked                           → LockView (실제 인증 화면)
//   - 잠금이 꺼진 상태에서 켜기 인증 중에는 useFaceIDLock이 아직 false이므로 덮개가 나오지 않는다.
//

import SwiftUI

struct RootView: View {
    @Environment(\.di) private var di
    @Environment(\.scenePhase) private var scenePhase

    @State private var lock = AppLockController()
    @State private var hasCompletedOnboarding =
        UserDefaults.standard.bool(forKey: AppSettings.Keys.hasCompletedOnboarding)

    /// 잠금 설정이 켜져 있는지. 앱 전환기 덮개 노출 판단에 쓴다.
    private var lockEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.Keys.useFaceIDLock)
    }

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(analysisService: di.analysisService) {
                    hasCompletedOnboarding = true
                }
            }

            // 잠금 화면 또는 앱 전환기 덮개 (잠금 화면이 우선)
            if lock.isLocked {
                LockView(isAuthenticating: lock.isAuthenticating) {
                    Task { await lock.retry() }
                }
            } else if lockEnabled && scenePhase != .active {
                // 잠금이 켜진 채 비활성 상태일 때만 내용을 가린다.
                // (잠금 OFF 상태에서 켜기 인증 중에는 덮개가 나오지 않는다.)
                Color.bhBackground.ignoresSafeArea()
            }
        }
        .task {
            // 콜드 런치 시 잠겨 있으면 인증을 시도한다.
            await lock.authenticateIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // 백그라운드 진입 시 즉시 잠근다. (녹음 정지·보존은 RecordFlowView가 독립적으로 수행)
                lock.enterBackground()
            case .active:
                // 백그라운드에서 돌아온 복귀일 때만 재인증. (Face ID 팝업 복귀는 제외)
                if lock.consumeBackgroundReturn() {
                    Task { await lock.authenticateIfNeeded() }
                }
            case .inactive:
                // 덮개만 담당(위 body). 잠금 상태는 바꾸지 않는다.
                break
            @unknown default:
                break
            }
        }
    }
}
