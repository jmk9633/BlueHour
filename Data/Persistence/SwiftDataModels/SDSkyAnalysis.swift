//
//  SDSkyAnalysis.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

@Model
final class SDSkyAnalysis {
    var weatherTypeRaw: String
    var title: String
    var summary: String
    var emotionKeywords: [String]
    var mainTheme: String?
    var recoverySignal: String?
    var tomorrowSentence: String
    var analyzedAt: Date

    init(
        weatherTypeRaw: String,
        title: String,
        summary: String,
        emotionKeywords: [String],
        mainTheme: String?,
        recoverySignal: String?,
        tomorrowSentence: String,
        analyzedAt: Date
    ) {
        self.weatherTypeRaw = weatherTypeRaw
        self.title = title
        self.summary = summary
        self.emotionKeywords = emotionKeywords
        self.mainTheme = mainTheme
        self.recoverySignal = recoverySignal
        self.tomorrowSentence = tomorrowSentence
        self.analyzedAt = analyzedAt
    }
}
