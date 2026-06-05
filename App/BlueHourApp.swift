//
//  BlueHourApp.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import SwiftUI
import SwiftData

@main
struct BlueHourApp: App {

    // 1. SwiftData 저장소 (앱 전체에서 하나만)
    private let modelContainer: ModelContainer

    // 2. DI 관리실 (모든 일꾼을 모아둔 곳)
    @State private var container: DIContainer

    init() {
        // SwiftData 컨테이너 생성
        let modelContainer = BlueHourModelContainer.make()
        self.modelContainer = modelContainer

        // DI 컨테이너 생성 후, ModelContext 연결
        let di = DIContainer()
        di.setup(modelContext: modelContainer.mainContext)
        _container = State(initialValue: di)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .diContainer(container)              // 화면 전체에 DI 주입
        }
        .modelContainer(modelContainer)              // SwiftData 주입
    }
}


#Preview {
    ResultView(analysis: .preview) { }
}
