//
//  RecordFlowViewModel.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class RecordFlowViewModel {

    // MARK: - 화면이 바라보는 상태

    private(set) var state: RecordFlowState = .idle

    /// 녹음 경과 시간 (초). 녹음 화면의 타이머가 이 값을 표시.
    private(set) var elapsedTime: TimeInterval = 0

    /// 변환된 텍스트. reviewing 단계에서 사용자가 수정할 수 있음.
    var editableText: String = ""

    /// 완성된 오늘의 하늘. result 단계에서 결과 화면이 표시.
    private(set) var analysis: SkyAnalysis?

    // MARK: - 설정값

    let maxDuration: TimeInterval = 60   // 최대 60초

    // MARK: - 의존성 (일꾼들)

    private let audioService: AudioRecordingService
    private let speechService: SpeechRecognitionService
    private let analysisService: SkyAnalysisService
    private let repository: DiaryRepositoryProtocol

    // MARK: - 내부 상태

    private var recordedFileName: String?
    private var recordedDuration: TimeInterval = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - 초기화

    init(
        audioService: AudioRecordingService,
        speechService: SpeechRecognitionService,
        analysisService: SkyAnalysisService,
        repository: DiaryRepositoryProtocol
    ) {
        self.audioService = audioService
        self.speechService = speechService
        self.analysisService = analysisService
        self.repository = repository
    }

    // MARK: - 1. 녹음 시작

    func startRecording() async {
        // 권한 확인
        let micGranted = await audioService.requestPermission()
        guard micGranted else {
            state = .failed("마이크 권한이 필요해요. 설정에서 허용해 주세요.")
            return
        }
        _ = await speechService.requestPermission()

        do {
            let fileName = try await audioService.startRecording()
            recordedFileName = fileName
            elapsedTime = 0
            state = .recording
            startTimer()
        } catch {
            state = .failed("녹음을 시작할 수 없어요.")
        }
    }

    // MARK: - 2. 녹음 정지 → 변환

    func stopRecording() async {
        stopTimer()
        do {
            let (fileName, duration) = try await audioService.stopRecording()
            recordedFileName = fileName
            recordedDuration = duration
            await transcribe(fileName: fileName)
        } catch {
            state = .failed("녹음을 마칠 수 없어요.")
        }
    }

    // MARK: - 다시 말하기 (녹음 취소 후 처음으로)

    func restart() async {
        stopTimer()
        await audioService.cancelRecording()
        recordedFileName = nil
        recordedDuration = 0
        elapsedTime = 0
        editableText = ""
        analysis = nil
        state = .idle
    }

    // MARK: - 3. 음성 → 글자

    private func transcribe(fileName: String) async {
        state = .transcribing
        do {
            let transcript = try await speechService.transcribe(
                fileName: fileName,
                languageCode: "ko-KR"
            )
            let text = transcript.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            // 비어 있어도 오류가 아님 — 사용자가 직접 적도록 수정 화면으로
            editableText = text
            state = .reviewing
        } catch {
            // 인식 실패도 막다른 길이 아님 — 빈 칸으로 직접 쓰게 함
            print("ℹ️ 음성 인식 실패, 직접 입력으로 전환:", error)
            editableText = ""
            state = .reviewing
        }
    }

    // MARK: - 4. 확인 완료 → AI 분석 → 저장

    func confirmAndAnalyze() async {
        let text = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state = .failed("오늘 말한 내용이 비어 있어요.")
            return
        }

        state = .analyzing
        do {
            let sky = try await analysisService.analyze(text: text)
            self.analysis = sky
            try await save(text: text, sky: sky)
            state = .result
        } catch {
            state = .failed("오늘의 하늘을 만들지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    // MARK: - 저장 (도메인 모델 조립 후 리포지토리에 위임)

    private func save(text: String, sky: SkyAnalysis) async throws {
        let recording: VoiceRecording? = recordedFileName.map { name in
            VoiceRecording(fileName: name, duration: recordedDuration)
        }
        let transcript = DiaryTranscript(originalText: text, editedText: nil)

        let entry = DiaryEntry(
            date: .now,
            recording: recording,
            transcript: transcript,
            analysis: sky
        )
        try await repository.save(entry)
    }

    // MARK: - 타이머 (60초 도달 시 자동 정지)

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.1))
                guard state == .recording else { break }
                elapsedTime += 0.1
                if elapsedTime >= maxDuration {
                    await stopRecording()
                    break
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
