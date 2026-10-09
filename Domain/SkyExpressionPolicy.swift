//
//  SkyExpressionPolicy.swift
//  BlueHour
//
//  AI 분석 표현 정책(PL-XNEFLR, 비진단)의 안전망 로직.
//  - 모델 호출 없이 금지어·유사 표현 목록으로만 위험 표현을 판별한다.
//  - 위험 표현이 걸린 '필드만' 대체하며, weatherType은 언제나 유지한다.
//
//  ⚠️ 금지어 목록은 초안이며 테스트하며 보완한다. (기획서 PL-XNEFLR와 동기화 필요)
//     과검출을 줄이기 위해:
//       · 단일 글자 '약'은 제외하고 '약물/복용/약을 먹/약 복용'처럼 구체화했다.
//       · '수치'는 '수치심'을 예외로 두어 걸리지 않게 했다.
//       · 2글자 이하 짧은 금지어는 공백을 지우지 않은 원문에서 검사해, 단어가 붙어 생기는
//         오검출(예: '점 수' → '점수')을 피한다.
//

import Foundation

struct SkyExpressionPolicy: Sendable {

    // MARK: - 목록 (초안)

    /// 금지어와 글자가 겹치지만 위험하지 않은 표현. 검사 전에 제거한다.
    static let exceptions: [String] = [
        "수치심"
    ]

    /// 2글자 이하 짧은 금지어. 공백을 보존한 원문에서 검사한다.
    static let shortBannedTerms: [String] = [
        // 진단·임상
        "우울", "공황", "강박", "조울", "진단", "증상", "치료", "병원", "약물", "복용",
        // 평가·판정
        "수치", "지수", "점수", "레벨", "단계"
    ]

    /// 3글자 이상 금지어/구문. 공백·문장부호를 제거한 뒤 검사한다.
    static let longBannedTerms: [String] = [
        // 진단·임상
        "우울증", "불안장애", "번아웃", "트라우마", "ptsd", "adhd", "불면증", "섭식장애",
        "전문가", "상담이필요", "약을먹", "약복용", "불안수치", "불안증상",
        // 평가·판정
        "위험군", "고위험", "비정상", "정상범위", "정상수치", "정상입니다", "정상이에요",
        "상태입니다", "당신은", "해야해요", "해야합니다"
    ]

    /// 날씨 유형별 대체 요약 문장 (summary가 걸렸을 때 사용).
    static let replacementSummaries: [SkyWeatherType: String] = [
        .clearNight: "오늘의 마음은 맑은 밤하늘처럼 조용히 펼쳐져 있었어요.",
        .partlyCloudy: "구름이 조금 지나갔지만 하늘은 제 빛을 잃지 않은 하루였어요.",
        .cloudyNight: "구름이 낮게 드리운 밤처럼 마음이 조금 무거웠던 하루였어요.",
        .lightRain: "마음에 얇은 비가 조용히 내린 하루였어요.",
        .shower: "잠깐 세찬 비가 지나간 것처럼 마음이 크게 흔들린 순간이 있었던 하루였어요.",
        .fog: "안개 낀 밤처럼 마음이 또렷하게 보이지 않던 하루였어요.",
        .windy: "바람이 많이 불던 밤처럼 마음이 이리저리 움직인 하루였어요.",
        .sunset: "하루 끝에 노을이 번지듯 따뜻한 빛이 남아 있던 하루였어요.",
        .moonlight: "달빛이 고요하게 내려앉은 것처럼 차분하게 흘러간 하루였어요.",
        .lightThroughClouds: "구름 사이로 작은 빛이 스며든 것처럼 조금 숨을 돌린 하루였어요."
    ]

    /// 공통 대체 내일 문장 (tomorrowSentence가 걸렸을 때 사용).
    static let commonTomorrowSentences: [String] = [
        "오늘을 말해준 것만으로도 충분해요.",
        "내일의 하늘은 내일 천천히 만나요.",
        "어떤 하늘이었든, 오늘을 잘 건너왔어요.",
        "오늘은 여기까지, 편안한 밤 보내요."
    ]

    init() {}

    // MARK: - 위험 표현 판별

    /// 한 문자열에 금지어가 들어 있는지.
    func isRisky(_ text: String) -> Bool {
        // 1) 예외 표현을 공백으로 치환해 제거 (글자가 붙어 오검출되지 않도록)
        var lowered = text.lowercased()
        for exception in Self.exceptions {
            lowered = lowered.replacingOccurrences(of: exception, with: " ")
        }

        // 2) 짧은 금지어: 공백 보존(문장부호만 제거)한 원문에서 검사
        let spaced = Self.stripPunctuation(lowered, keepingSpaces: true)
        for term in Self.shortBannedTerms where spaced.contains(term) {
            return true
        }

        // 3) 긴 금지어/구문: 공백·문장부호 제거 후 검사
        let compact = Self.stripPunctuation(lowered, keepingSpaces: false)
        for term in Self.longBannedTerms where compact.contains(term) {
            return true
        }

        return false
    }

    /// SkyAnalysis의 어느 텍스트 필드든 위험 표현을 담고 있는지. (재생성 여부 판단용)
    func hasAnyRisky(_ analysis: SkyAnalysis) -> Bool {
        if isRisky(analysis.title) { return true }
        if isRisky(analysis.summary) { return true }
        if isRisky(analysis.tomorrowSentence) { return true }
        if analysis.emotionKeywords.contains(where: isRisky) { return true }
        if let theme = analysis.mainTheme, isRisky(theme) { return true }
        if let recovery = analysis.recoverySignal, isRisky(recovery) { return true }
        return false
    }

    // MARK: - 필드별 대체

    /// 위험 표현이 걸린 필드만 대체한 새 SkyAnalysis를 돌려준다. weatherType은 유지한다.
    func sanitize(_ analysis: SkyAnalysis) -> SkyAnalysis {
        var result = analysis

        if isRisky(analysis.title) {
            result.title = analysis.weatherType.displayName
        }
        if isRisky(analysis.summary) {
            result.summary = Self.replacementSummaries[analysis.weatherType] ?? analysis.weatherType.displayName
        }
        if isRisky(analysis.tomorrowSentence) {
            result.tomorrowSentence = commonTomorrowSentence(for: analysis.weatherType)
        }
        // 걸린 키워드만 제거하고 나머지는 유지 (모두 빠지면 빈 배열 → 화면에서 영역 숨김)
        result.emotionKeywords = analysis.emotionKeywords.filter { !isRisky($0) }

        if let theme = analysis.mainTheme, isRisky(theme) {
            result.mainTheme = nil
        }
        if let recovery = analysis.recoverySignal, isRisky(recovery) {
            result.recoverySignal = nil
        }

        return result
    }

    /// 공통 대체 내일 문장을 weatherType으로부터 결정적으로 고른다. (테스트 가능하도록 고정)
    func commonTomorrowSentence(for type: SkyWeatherType) -> String {
        let index = (SkyWeatherType.allCases.firstIndex(of: type) ?? 0) % Self.commonTomorrowSentences.count
        return Self.commonTomorrowSentences[index]
    }

    // MARK: - Private

    /// 영문/숫자/한글은 남기고 문장부호·기호를 제거한다. keepingSpaces가 false면 공백도 제거한다.
    private static func stripPunctuation(_ text: String, keepingSpaces: Bool) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            if CharacterSet.alphanumerics.contains(scalar) { return true }
            if keepingSpaces && scalar == " " { return true }
            return false
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
