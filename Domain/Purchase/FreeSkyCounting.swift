//
//  FreeSkyCounting.swift
//  BlueHour
//
//  무료 하늘 카운트(F-XUQOXA)와 그 영구 저장소(키체인)의 추상화.
//  카운트는 '지금까지 새로 만든 기록 수'이며, 삭제·재설치에도 유지된다. (PL-OBQXIP)
//

import Foundation

/// 무료 하늘 카운트를 영구 보관하는 저장소. 실제 구현은 키체인, 테스트는 인메모리가 대신한다.
protocol FreeSkyCountStoring: Sendable {
    func load() -> Int
    func save(_ count: Int)
}

/// 무료 하늘 카운트를 읽고 늘리는 창구. 감소 메서드는 없다(삭제해도 줄지 않음).
@MainActor
protocol FreeSkyCounting: AnyObject {
    var count: Int { get }
    var limit: Int { get }
    var hasReachedLimit: Bool { get }
    func increment()
}
