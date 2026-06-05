//
//  SpeechRecognitionService.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import Speech

actor SpeechRecognitionService: SpeechRecognitionServiceProtocol {

    // 음성 파일 경로를 얻기 위해 녹음 일꾼을 참조
    private let audioService: AudioRecordingService

    init(audioService: AudioRecordingService) {
        self.audioService = audioService
    }

    // MARK: - 권한

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - 변환

    func transcribe(fileName: String, languageCode: String) async throws -> DiaryTranscript {
        guard let recognizer = SFSpeechRecognizer(
            locale: Locale(identifier: languageCode)
        ), recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        let fileURL = await audioService.fileURL(for: fileName)
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true  // 온디바이스 우선 (프라이버시)

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: SpeechRecognitionError.transcriptionFailed)
                    return
                }
                guard let result, result.isFinal else { return }

                let transcript = DiaryTranscript(
                    originalText: result.bestTranscription.formattedString,
                    editedText: nil,
                    languageCode: languageCode,
                    confidence: Self.averageConfidence(of: result)
                )
                continuation.resume(returning: transcript)
            }
        }
    }

    // MARK: - Private

    private static func averageConfidence(of result: SFSpeechRecognitionResult) -> Double? {
        let segments = result.bestTranscription.segments
        guard !segments.isEmpty else { return nil }
        let total = segments.reduce(0.0) { $0 + Double($1.confidence) }
        return total / Double(segments.count)
    }
}
