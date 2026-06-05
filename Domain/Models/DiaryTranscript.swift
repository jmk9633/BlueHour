//
//  DiaryTranscript.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

struct DiaryTranscript: Equatable, Sendable {
    var originalText: String
    var editedText: String?
    var languageCode: String
    var confidence: Double?

    /// 사용자가 수정한 텍스트가 있으면 우선, 없으면 원본
    var displayText: String {
        editedText ?? originalText
    }

    init(
        originalText: String,
        editedText: String? = nil,
        languageCode: String = "ko-KR",
        confidence: Double? = nil
    ) {
        self.originalText = originalText
        self.editedText = editedText
        self.languageCode = languageCode
        self.confidence = confidence
    }
}
