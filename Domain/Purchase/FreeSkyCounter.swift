//
//  FreeSkyCounter.swift
//  BlueHour
//
//  무료 하늘 카운트(F-XUQOXA). 한도는 30개이며, 새 기록이 저장될 때만 1 늘어난다.
//  저장소는 키체인(앱 삭제·전체 삭제에도 유지)이며, 감소는 제공하지 않는다. (PL-OBQXIP)
//

import Foundation
import Observation

@MainActor
@Observable
final class FreeSkyCounter: FreeSkyCounting {

    /// 무료로 만들 수 있는 하늘 수.
    let limit: Int

    /// 지금까지 새로 만든 하늘 수.
    private(set) var count: Int

    private let store: FreeSkyCountStoring

    init(store: FreeSkyCountStoring, limit: Int = 30) {
        self.store = store
        self.limit = limit
        self.count = store.load()
    }

    /// 한도에 도달했는지(미구매 사용자의 새 기록 차단 판단).
    var hasReachedLimit: Bool { count >= limit }

    /// 새 기록 저장이 끝났을 때만 호출한다.
    func increment() {
        count += 1
        store.save(count)
    }
}
