//
//  RecordFlowState.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation

/// 오늘 말하기 흐름의 현재 단계.
/// ViewModel이 이 상태를 바꾸면 화면이 그에 맞춰 전환된다.
enum RecordFlowState: Equatable {
    case idle              // 시작 전 (오늘 화면)
    case recording         // 녹음 중
    case transcribing      // 음성 → 글자 변환 중
    case reviewing         // 변환된 텍스트 확인/수정
    case analyzing         // AI가 하늘을 읽는 중
    case result            // 오늘의 하늘 완성
    case failed(String)    // 오류 발생 (메시지 포함)
}
