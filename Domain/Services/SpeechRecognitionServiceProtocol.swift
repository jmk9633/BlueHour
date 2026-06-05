//
//  SpeechRecognitionServiceProtocol.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

enum SpeechRecognitionError: Error, Sendable {
    case permissionDenied
    case recognizerUnavailable
    case transcriptionFailed
}

protocol SpeechRecognitionServiceProtocol: Sendable {
    func requestPermission() async -> Bool

    /// 저장된 음성 파일을 텍스트로 변환
    func transcribe(fileName: String, languageCode: String) async throws -> DiaryTranscript
}
