//
//  DIContainer+Environment.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

// SwiftUI 환경에 DIContainer를 실어 나르기 위한 키
private struct DIContainerKey: EnvironmentKey {
    @MainActor
    static var defaultValue: DIContainer = DIContainer()
}

extension EnvironmentValues {
    var di: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

extension View {
    /// 화면 트리에 DIContainer를 주입하는 편의 modifier
    func diContainer(_ container: DIContainer) -> some View {
        environment(\.di, container)
    }
}
