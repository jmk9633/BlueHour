//
//  SDDiaryTranscript.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

@Model
final class SDDiaryTranscript {
    var originalText: String
    var editedText: String?
    var languageCode: String
    var confidence: Double?

    init(
        originalText: String,
        editedText: String?,
        languageCode: String,
        confidence: Double?
    ) {
        self.originalText = originalText
        self.editedText = editedText
        self.languageCode = languageCode
        self.confidence = confidence
    }
}
