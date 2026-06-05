//
//  MainTabView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct MainTabView: View {
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
    }
}
