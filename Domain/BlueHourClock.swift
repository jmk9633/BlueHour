//
//  BlueHourClock.swift
//  BlueHour
//
//  앱 전역의 "현재 시각" 출처. 기본은 실제 시계(Date()).
//  '오늘/현재'를 판단하거나 작성 시각을 기록하는 곳은 Date()·.now 대신 이 시계를 읽는다.
//  Release에서는 교체되지 않으므로 항상 실제 시각을 돌려준다.
//  DEBUG 개발자 도구(현재 시각 바꾸기)에서만 now를 교체해 가짜 시각으로 돌릴 수 있다.
//

import Foundation

enum BlueHourClock {
    /// 현재 시각을 돌려주는 클로저. 기본은 실제 시계.
    /// DEBUG 전용 도구에서만 메인 스레드에서 교체한다.
    nonisolated(unsafe) static var now: () -> Date = { Date() }
}
