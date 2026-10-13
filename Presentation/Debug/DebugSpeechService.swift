//
//  DebugSpeechService.swift
//  BlueHour
//
//  DEBUG 전용: 실제 SpeechRecognitionService를 감싸 음성 인식 결과(#6)를 강제한다.
//  '실제 따름'이면 그대로 위임한다.
//

#if DEBUG
import Foundation

struct DebugSpeechService: SpeechRecognitionServiceProtocol {

    private let wrapped: SpeechRecognitionServiceProtocol

    init(wrapping wrapped: SpeechRecognitionServiceProtocol) {
        self.wrapped = wrapped
    }

    func requestPermission() async -> Bool {
        // 권한은 변환 강제와 무관하므로, 실제 따름이면 위임하고 강제 모드에선 통과시킨다.
        switch await currentMode() {
        case .follow: return await wrapped.requestPermission()
        case .fail, .timeout: return true
        }
    }

    func transcribe(fileName: String, languageCode: String) async throws -> DiaryTranscript {
        switch await currentMode() {
        case .follow:
            return try await wrapped.transcribe(fileName: fileName, languageCode: languageCode)
        case .fail:
            throw SpeechRecognitionError.transcriptionFailed
        case .timeout:
            // 8초를 기다린 뒤 타임아웃으로 실패시킨다.
            try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
            throw SpeechRecognitionError.transcriptionFailed
        }
    }

    private func currentMode() async -> DebugSettings.SpeechMode {
        await MainActor.run { DebugSettings.shared.speechMode }
    }
}
#endif
