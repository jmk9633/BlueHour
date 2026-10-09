//
//  MainTabView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct MainTabView: View {
    @Environment(\.di) private var di
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            RecordFlowView()
                .tabItem {
                    Label("오늘", systemImage: "moon.stars")
                }

            SkyCalendarView()
                .tabItem {
                    Label("하늘", systemImage: "cloud.moon")
                }

            SettingsView()
                .tabItem {
                    Label("나", systemImage: "person")
                }
        }
        .tint(Color.bhAccent)
        // 앱 실행 시, 그리고 포그라운드로 돌아올 때 '아직 그려지지 않은 하늘'을 자동 분석한다.
        // (PendingSkyAnalyzer가 중복 실행과 AI 미사용 상태를 스스로 막는다.)
        .task {
            await di.pendingAnalyzer.run()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await di.pendingAnalyzer.run() }
            }
        }
    }
}
