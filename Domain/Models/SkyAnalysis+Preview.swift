//
//  SkyAnalysis+Preview.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation

#if DEBUG
extension SkyAnalysis {
    /// Xcode 프리뷰/테스트용 샘플 하늘
    static var preview: SkyAnalysis {
        SkyAnalysis(
            weatherType: .lightThroughClouds,
            title: "흐린 밤, 구름 사이 작은 빛",
            summary: "에너지는 낮았지만 하루 끝에는 조금 숨을 돌릴 수 있었던 날이에요.",
            emotionKeywords: ["피로", "답답함", "안도", "회복"],
            mainTheme: "해야 할 일이 많다는 부담감이 있었지만 혼자 있는 시간이 회복에 가까웠어요.",
            recoverySignal: "혼자 있는 시간",
            tomorrowSentence: "다 해내려고 하지 말고 하나만 가볍게 시작해도 괜찮아."
        )
    }
}
#endif
