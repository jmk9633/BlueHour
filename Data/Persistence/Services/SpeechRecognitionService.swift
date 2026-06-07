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
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            // continuation이 한 번만 호출되도록 보호하는 플래그
            let hasResumed = ResumeGuard()
            var task: SFSpeechRecognitionTask?

            // 안전장치: 8초 안에 final이 안 오면 지금까지의 결과로 마무리
            let timeout = Task {
                try? await Task.sleep(for: .seconds(8))
                if await hasResumed.markIfNeeded() {
                    task?.cancel()
                    // 부분 결과조차 없으면 빈 텍스트로 (오류 아님)
                    let empty = DiaryTranscript(
                        originalText: "",
                        editedText: nil,
                        languageCode: languageCode,
                        confidence: nil
                    )
                    continuation.resume(returning: empty)
                }
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                Task {
                    if let error {
                        if await hasResumed.markIfNeeded() {
                            timeout.cancel()
                            continuation.resume(throwing: SpeechRecognitionError.transcriptionFailed)
                        }
                        return
                    }
                    guard let result, result.isFinal else { return }

                    if await hasResumed.markIfNeeded() {
                        timeout.cancel()
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

/// continuation이 두 번 호출되어 크래시 나는 걸 막는 안전장치.
/// markIfNeeded()는 처음 호출될 때만 true를 돌려준다.
private actor ResumeGuard {
    private var resumed = false
    func markIfNeeded() -> Bool {
        guard !resumed else { return false }
        resumed = true
        return true
    }
}
