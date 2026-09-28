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

    /// 녹음이 일시중지 상태인지 여부.
    private(set) var isPaused: Bool = false

    /// 변환된 텍스트. reviewing 단계에서 사용자가 수정할 수 있음.
    var editableText: String = ""

    /// 완성된 오늘의 하늘. result 단계에서 결과 화면이 표시.
    private(set) var analysis: SkyAnalysis?

    /// 대상 날짜에 이미 저장된 기록. 있으면 오늘 탭이 '오늘의 하늘'(또는 아직 그려지지 않은 하늘)을 보여준다.
    /// 없으면 빈 하늘 안내와 [오늘 말하기] 버튼을 보여준다.
    private(set) var existingEntry: DiaryEntry?

    // MARK: - 설정값

    let maxDuration: TimeInterval = 60   // 최대 60초

    /// 이 기록이 저장될 대상 날짜. 오늘 탭은 논리적 오늘의 자정, 캘린더에서 과거 날짜를 고르면 그 날(자정).
    let targetDate: Date

    /// 대상 날짜가 (논리적) 오늘인지 여부. 오늘이 아니면 화면 상단에 대상일 헤더를 보여준다.
    var isTargetToday: Bool {
        BlueHourCalendar.isLogicalToday(targetDate)
    }

    /// 대상일 헤더에 표시할 문자열. 예: "6월 3일 화요일"
    var targetDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: targetDate)
    }

    // MARK: - 의존성 (일꾼들)

    private let audioService: AudioRecordingService
    private let speechService: SpeechRecognitionService
    private let analysisService: SkyAnalysisService
    private let repository: DiaryRepositoryProtocol

    // MARK: - 내부 상태

    private var recordedFileName: String?
    private var recordedDuration: TimeInterval = 0
    private var timerTask: Task<Void, Never>?

    /// 기존 기록을 텍스트로 수정하는 중이면 그 엔트리. 저장 시 새로 만들지 않고 이 엔트리를 덮어쓴다.
    private var editingEntry: DiaryEntry?

    /// 저장 시 대상 날짜의 기존 기록을 지우고 교체할지 여부.
    /// 하루 1개 정책은 '진입 단계'에서 막으므로 신규 흐름은 false로 둔다.
    /// 이 교체 경로는 향후 '다시 말하기(F-PFVBLO)'가 true로 재사용한다.
    private let replaceExisting: Bool

    // MARK: - 초기화

    init(
        targetDate: Date,
        replaceExisting: Bool = false,
        audioService: AudioRecordingService,
        speechService: SpeechRecognitionService,
        analysisService: SkyAnalysisService,
        repository: DiaryRepositoryProtocol
    ) {
        self.targetDate = targetDate
        self.replaceExisting = replaceExisting
        self.audioService = audioService
        self.speechService = speechService
        self.analysisService = analysisService
        self.repository = repository
    }

    // MARK: - 대상 날짜의 기존 기록 확인 (진입/복귀/저장 후 호출)

    /// 대상 날짜에 저장된 기록을 다시 불러와 existingEntry에 반영한다.
    /// 텍스트 수정 모드(editingEntry)일 때는 리뷰 화면을 유지해야 하므로 건너뛴다.
    func loadExistingEntry() async {
        guard editingEntry == nil else { return }
        existingEntry = try? await repository.fetchEntry(on: targetDate)
    }

    // MARK: - 1. 녹음 시작

    func startRecording() async {
        // 하루 1개 정책: 이미 기록이 있으면 새 녹음을 시작하지 않는다(진입 단계 차단).
        guard existingEntry == nil else { return }

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
            isPaused = false
            state = .recording
            startTimer()
        } catch {
            state = .failed("녹음을 시작할 수 없어요.")
        }
    }

    // MARK: - 녹음 일시중지 / 이어서 시작

    func pauseRecording() async {
        guard state == .recording, !isPaused else { return }
        await audioService.pauseRecording()
        isPaused = true
    }

    func resumeRecording() async {
        guard state == .recording, isPaused else { return }
        do {
            try await audioService.resumeRecording()
            isPaused = false
        } catch {
            state = .failed("녹음을 이어서 진행할 수 없어요.")
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
        isPaused = false
        editableText = ""
        analysis = nil
        state = .idle
        // 저장 후 결과 화면을 닫고 돌아왔을 수 있으므로, 최신 기록 상태를 다시 반영한다.
        await loadExistingEntry()
    }

    // MARK: - 기존 기록 텍스트 수정으로 진입 (녹음 없이 바로 리뷰 화면)

    /// 캘린더에서 기존 하늘의 "수정"을 누르면 호출. 기존 텍스트를 채운 채 리뷰 화면으로 연다.
    func startTextEdit(entry: DiaryEntry) {
        editingEntry = entry
        editableText = entry.transcript?.displayText ?? ""
        recordedFileName = entry.recording?.fileName
        recordedDuration = entry.recording?.duration ?? 0
        analysis = entry.analysis
        state = .reviewing
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
        // 수정 모드: 기존 엔트리를 덮어쓴다 (id·date·녹음 유지, transcript·analysis·updatedAt 갱신).
        if let editing = editingEntry {
            let transcript = DiaryTranscript(
                originalText: editing.transcript?.originalText ?? text,
                editedText: text
            )
            let updated = DiaryEntry(
                id: editing.id,
                date: editing.date,
                recording: editing.recording,
                transcript: transcript,
                analysis: sky,
                createdAt: editing.createdAt,
                updatedAt: .now
            )
            try await repository.update(updated)
            return
        }

        // 교체 모드('다시 말하기' 등)에서만 대상 날짜의 기존 기록을 정리한다.
        // 신규 흐름은 진입 단계에서 하루 1개를 보장하므로 여기서 지우지 않는다.
        if replaceExisting {
            try await replaceExistingEntries(on: targetDate)
        }

        let recording: VoiceRecording? = recordedFileName.map { name in
            VoiceRecording(fileName: name, duration: recordedDuration)
        }
        let transcript = DiaryTranscript(originalText: text, editedText: nil)

        // date는 대상 날짜(논리적 하루의 자정)로 정규화해 저장하고, createdAt은 실제 시각(기본값)을 둔다.
        let entry = DiaryEntry(
            date: targetDate,
            recording: recording,
            transcript: transcript,
            analysis: sky
        )
        try await repository.save(entry)
    }

    /// 대상 날짜에 등록된 기록을 모두 지운다(음성 파일 포함).
    /// 향후 '다시 말하기(F-PFVBLO)'가 재사용할 교체 경로.
    private func replaceExistingEntries(on date: Date) async throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let existing = try await repository.fetchEntries(
            in: DateInterval(start: dayStart, end: dayEnd)
        )
        for entry in existing {
            // 기존 음성 파일이 있으면 디스크에서도 정리
            if let oldFileName = entry.recording?.fileName {
                try? await audioService.deleteRecording(fileName: oldFileName)
            }
            try await repository.delete(id: entry.id)
        }
    }

    // MARK: - 타이머 (60초 도달 시 자동 정지)

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.1))
                guard state == .recording else { break }
                // 일시중지 중에는 시간이 흐르지 않음
                guard !isPaused else { continue }
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
