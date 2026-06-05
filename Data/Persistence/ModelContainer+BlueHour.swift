//
//  ModelContainer+BlueHour.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

enum BlueHourModelContainer {

    static let schema = Schema([
        SDDiaryEntry.self,
        SDVoiceRecording.self,
        SDDiaryTranscript.self,
        SDSkyAnalysis.self
    ])

    /// 앱 실행용 영속 컨테이너 (Local First, 서버 없음)
    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }

    /// 프리뷰/테스트용 인메모리 컨테이너
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("인메모리 ModelContainer 생성 실패: \(error)")
        }
    }
}
