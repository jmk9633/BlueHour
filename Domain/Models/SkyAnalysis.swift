//
//  SkyAnalysis.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

struct SkyAnalysis: Equatable, Sendable {
    var weatherType: SkyWeatherType
    var title: String
    var summary: String
    var emotionKeywords: [String]
    var mainTheme: String?
    var recoverySignal: String?
    var tomorrowSentence: String
    var analyzedAt: Date

    init(
        weatherType: SkyWeatherType,
        title: String,
        summary: String,
        emotionKeywords: [String],
        mainTheme: String? = nil,
        recoverySignal: String? = nil,
        tomorrowSentence: String,
        analyzedAt: Date = .now
    ) {
        self.weatherType = weatherType
        self.title = title
        self.summary = summary
        self.emotionKeywords = emotionKeywords
        self.mainTheme = mainTheme
        self.recoverySignal = recoverySignal
        self.tomorrowSentence = tomorrowSentence
        self.analyzedAt = analyzedAt
    }
}
