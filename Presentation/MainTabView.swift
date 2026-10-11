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
        TabView(selection: Bindable(di.tabRouter).selection) {
            RecordFlowView()
                .tabItem {
                    Label("오늘", systemImage: "moon.stars")
                }
                .tag(TabRouter.todayTab)

            SkyCalendarView()
                .tabItem {
                    Label("하늘", systemImage: "cloud.moon")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("나", systemImage: "person")
                }
                .tag(2)
        }
        .tint(Color.bhAccent)
        // 앱 실행 시, 그리고 포그라운드로 돌아올 때:
        //  - '아직 그려지지 않은 하늘'을 자동 분석한다. (PendingSkyAnalyzer가 중복/미사용을 스스로 막음)
        //  - 밤 리마인더 예약을 다시 맞추고, 권한이 꺼졌으면 토글을 꺼진 상태로 반영한다.
        .task {
            await di.pendingAnalyzer.run()
            await di.nightReminderController.refreshFromSystem()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await di.pendingAnalyzer.run() }
                Task { await di.nightReminderController.refreshFromSystem() }
            }
        }
    }
}
