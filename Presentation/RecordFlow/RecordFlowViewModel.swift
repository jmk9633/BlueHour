//
//  RecordFlowViewModel.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import Observation
import AVFoundation
import UIKit

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

    /// 무료 한도에 도달해 새 기록을 막아야 할 때 true. 화면이 구매 화면을 띄운다. (F-XUQOXA)
    var showPurchase: Bool = false

    /// 30번째 무료 하늘을 저장해 결과 카드에서 한 번 안내해야 할 때 true. (PL-OBQXIP)
    private(set) var reachedFreeLimitNotice: Bool = false

    // MARK: - 설정값

    let maxDuration: TimeInterval = 60   // 최대 60초
    let minimumDuration: TimeInterval = 3   // 3초 미만은 저장하지 않음

    /// 지금 녹음이 저장 가능한 최소 길이를 넘겼는지 (녹음 중 판단용).
    var isRecordingLongEnough: Bool {
        elapsedTime >= minimumDuration
    }

    /// 보존된(인터럽션으로 멈춘) 녹음이 저장 가능한 최소 길이를 넘겼는지.
    var canSavePreservedRecording: Bool {
        recordedDuration >= minimumDuration
    }

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

    private let audioService: AudioRecordingServiceProtocol
    private let speechService: SpeechRecognitionServiceProtocol
    private let analysisService: SkyAnalysisServiceProtocol
    private let repository: DiaryRepositoryProtocol
    private let defaults: UserDefaults

    /// 구매 여부(평생 이용권). nil이면 제한 없음(테스트 등).
    private let entitlement: EntitlementProviding?
    /// 무료 하늘 카운트. nil이면 카운트하지 않음(테스트 등).
    private let freeSkyCounter: FreeSkyCounting?

    // MARK: - 내부 상태

    private var recordedFileName: String?
    private var recordedDuration: TimeInterval = 0
    private var timerTask: Task<Void, Never>?
    // 옵저버 토큰. 등록·해제는 항상 MainActor에서 일어나고, deinit의 removeObserver는 스레드 안전하다.
    // (UI 상태가 아니므로 Observation 추적에서 제외한다.)
    @ObservationIgnored nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    /// 기존 기록을 텍스트로 수정하는 중이면 그 엔트리. 저장 시 새로 만들지 않고 이 엔트리를 덮어쓴다.
    private var editingEntry: DiaryEntry?

    /// 저장 시 대상 날짜의 기존 기록을 지우고 교체할지 여부.
    /// 하루 1개 정책은 '진입 단계'에서 막으므로 신규 흐름은 false로 둔다.
    /// 이 교체 경로는 향후 '다시 말하기(F-PFVBLO)'가 true로 재사용한다.
    private let replaceExisting: Bool

    /// 구매 화면을 연 직후, 구매 성공 시 이어갈 원래 입구 동작.
    private var pendingEntry: PendingEntry?

    private enum PendingEntry {
        case recording      // [오늘 말하기]
        case textWriting    // 텍스트로 쓰기
    }

    // MARK: - 초기화

    init(
        targetDate: Date,
        replaceExisting: Bool = false,
        audioService: AudioRecordingServiceProtocol,
        speechService: SpeechRecognitionServiceProtocol,
        analysisService: SkyAnalysisServiceProtocol,
        repository: DiaryRepositoryProtocol,
        defaults: UserDefaults = .standard,
        entitlement: EntitlementProviding? = nil,
        freeSkyCounter: FreeSkyCounting? = nil
    ) {
        self.targetDate = targetDate
        self.replaceExisting = replaceExisting
        self.audioService = audioService
        self.speechService = speechService
        self.analysisService = analysisService
        self.repository = repository
        self.defaults = defaults
        self.entitlement = entitlement
        self.freeSkyCounter = freeSkyCounter
    }

    // MARK: - 대상 날짜의 기존 기록 확인 (진입/복귀/저장 후 호출)

    /// 대상 날짜에 저장된 기록을 다시 불러와 existingEntry에 반영한다.
    /// - 텍스트 수정 모드(editingEntry)일 때는 리뷰 화면을 유지해야 하므로 건너뛴다.
    /// - 다시 말하기(replaceExisting) 모드에서는 기존 기록이 있어도 녹음을 새로 시작해야 하므로
    ///   existingEntry를 비워 둔 채(오늘 화면의 녹음 버튼을 노출) 건너뛴다.
    func loadExistingEntry() async {
        guard editingEntry == nil, !replaceExisting else { return }
        existingEntry = try? await repository.fetchEntry(on: targetDate)
    }

    // MARK: - 새 기록 입구 게이트 (무료 30개 / 구매)

    /// 새 기록을 시작해도 되는지. 구매 여부 확인이 끝날 때까지 기다린 뒤 판단한다.
    /// 수정·다시 말하기(replaceExisting)는 이 게이트를 거치지 않는다.
    func canStartNewEntry() async -> Bool {
        if replaceExisting { return true }
        return await NewEntryGate.canStartNewEntry(entitlement: entitlement, counter: freeSkyCounter)
    }

    /// [오늘 말하기] 입구. 권한 요청보다 먼저 게이트를 확인하고, 통과하면 녹음을 시작한다.
    func beginRecording() async {
        guard await canStartNewEntry() else {
            pendingEntry = .recording
            showPurchase = true
            return
        }
        await startRecording()
    }

    /// '텍스트로 쓰기' 입구. 게이트를 먼저 확인하고, 통과하면 녹음 없이 리뷰 화면으로 전환한다.
    func beginTextWriting() async {
        guard await canStartNewEntry() else {
            pendingEntry = .textWriting
            showPurchase = true
            return
        }
        writeWithoutRecording()
    }

    /// 구매 성공 후, 원래 하려던 입구의 동작으로 이어간다.
    func resumeAfterPurchase() async {
        showPurchase = false
        let entry = pendingEntry
        pendingEntry = nil
        switch entry {
        case .recording:
            await startRecording()
        case .textWriting:
            writeWithoutRecording()
        case .none:
            break
        }
    }

    // MARK: - 1. 녹음 시작

    func startRecording() async {
        // 하루 1개 정책: 이미 기록이 있으면 새 녹음을 시작하지 않는다(진입 단계 차단).
        guard existingEntry == nil else { return }

        // 안전망: 입구 게이트를 우회해 들어와도 한도를 넘긴 미구매 상태면 녹음을 시작하지 않는다.
        guard await canStartNewEntry() else {
            showPurchase = true
            return
        }

        // 권한 확인 — 거부되면 권한 안내 화면으로
        let micGranted = await audioService.requestPermission()
        guard micGranted else {
            state = .permissionDenied
            return
        }
        _ = await speechService.requestPermission()

        do {
            let fileName = try await audioService.startRecording()
            recordedFileName = fileName
            recordedDuration = 0
            elapsedTime = 0
            isPaused = false
            state = .recording
            setIdleTimer(disabled: true)   // 녹음 중 화면 자동 잠금 방지
            startTimer()
            startInterruptionObserver()
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

    // MARK: - 저장 요청 (3초 규칙 게이트)

    /// 사용자가 [저장하기]를 눌렀을 때 호출. 3초 미만이면 저장하지 않고 false를 돌려준다.
    /// (화면은 false일 때 '조금만 더 말해볼까요?' 안내를 띄우고 녹음을 계속 유지한다.)
    @discardableResult
    func requestSave() async -> Bool {
        guard isRecordingLongEnough else { return false }
        await stopRecording()
        return true
    }

    // MARK: - 2. 녹음 정지 → 변환

    func stopRecording() async {
        stopTimer()
        stopInterruptionObserver()
        setIdleTimer(disabled: false)
        do {
            let (fileName, duration) = try await audioService.stopRecording()
            recordedFileName = fileName
            recordedDuration = duration
            await transcribe(fileName: fileName)
        } catch {
            state = .failed("녹음을 마칠 수 없어요.")
        }
    }

    // MARK: - 인터럽션/백그라운드로 녹음이 멈춤 → 보존

    /// 전화 등 오디오 인터럽션이나 백그라운드 진입 시 녹음을 정지하고 지금까지의 녹음을 보존한다.
    /// 사용자는 복귀 후 [저장하기] 또는 [다시 말하기]를 고른다.
    func handleInterruption() async {
        guard state == .recording else { return }
        stopTimer()
        stopInterruptionObserver()
        setIdleTimer(disabled: false)
        isPaused = false
        do {
            let (fileName, duration) = try await audioService.stopRecording()
            recordedFileName = fileName
            recordedDuration = duration
        } catch {
            // 정지에 실패해도 지금까지의 파일명은 유지한 채 보존 화면으로 넘어간다.
        }
        state = .interrupted
    }

    /// 인터럽션 보존본으로 그대로 변환을 진행한다.
    func continueAfterInterruption() async {
        guard let fileName = recordedFileName else {
            await restart()
            return
        }
        await transcribe(fileName: fileName)
    }

    /// 인터럽션 보존본을 버리고 처음으로 돌아간다.
    func discardAfterInterruption() async {
        await restart()
    }

    // MARK: - 다시 말하기 (녹음 취소 후 처음으로)

    func restart() async {
        stopTimer()
        stopInterruptionObserver()
        setIdleTimer(disabled: false)
        await audioService.cancelRecording()
        // 저장되지 않은 고아 임시 파일 정리. 단, 편집 모드에서는 기존 기록의 음성을 지우면 안 되므로 건드리지 않는다.
        if editingEntry == nil, let name = recordedFileName {
            try? await audioService.deleteRecording(fileName: name)
        }
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

    // MARK: - 텍스트로 쓰기 (녹음 없이 바로 리뷰 화면)

    /// 마이크 권한 거부 등으로 음성을 쓸 수 없을 때, 녹음 없이 직접 입력으로 전환한다.
    func writeWithoutRecording() {
        recordedFileName = nil
        recordedDuration = 0
        editableText = ""
        state = .reviewing
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
            // 분석 실패 시 처리는 흐름에 따라 다르다.
            if editingEntry != nil {
                // 기록 수정 모드(F-ROLIZJ): 수정한 텍스트는 저장하되 이전 하늘(analysis)은 그대로 유지한다.
                // 이렇게 하면 사용자는 고친 글을 잃지 않고, 나중에 다시 분석을 시도할 수 있다.
                let previous = editingEntry?.analysis
                self.analysis = previous
                try? await save(text: text, sky: previous)
                state = previous == nil ? .savedWithoutSky : .result
            } else if case SkyAnalysisError.modelUnavailable = error {
                // 신규 흐름에서 AI를 쓸 수 없으면 하늘 없이 저장한다('아직 그려지지 않은 하늘').
                // 나중에 AI를 쓸 수 있게 되면 PendingSkyAnalyzer가 자동으로 하늘을 채운다.
                self.analysis = nil
                try? await save(text: text, sky: nil)
                state = .savedWithoutSky
            } else {
                state = .failed("오늘의 하늘을 만들지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    // MARK: - 저장 (도메인 모델 조립 후 리포지토리에 위임)

    private func save(text: String, sky: SkyAnalysis?) async throws {
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
            recordedFileName = nil
            return
        }

        // 교체 모드('다시 말하기')에서만 대상 날짜의 기존 기록을 정리한다.
        // 이 삭제는 '새 기록을 실제로 저장하는 지금 시점'에만 일어난다.
        // (녹음 시작·녹음 중 취소·텍스트 확인 단계 이탈·앱 종료 시에는 기존 기록이 그대로 남는다.)
        // 신규 흐름은 진입 단계에서 하루 1개를 보장하므로 여기서 지우지 않는다.
        if replaceExisting {
            try await replaceExistingEntries(on: targetDate)
        }

        // 음성 저장 방식(saveOriginalAudio)은 '저장하는 지금 시점의 설정값'을 기준으로 적용한다.
        // (설정을 바꿔도 이미 저장된 기록에는 소급 적용하지 않는다.)
        let keepAudio = defaults.bool(forKey: AppSettings.Keys.saveOriginalAudio)
        var recording: VoiceRecording?
        if let name = recordedFileName {
            if keepAudio {
                recording = VoiceRecording(fileName: name, duration: recordedDuration)
            } else {
                // '글과 하늘만 남기기'이면 변환이 끝난 음성 파일을 삭제한다.
                try? await audioService.deleteRecording(fileName: name)
                recording = nil
            }
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
        // 저장이 끝난 파일은 이 흐름에서 더 이상 '임시 파일'이 아니므로 참조를 비운다.
        recordedFileName = nil

        // 무료 하늘 카운트: 새 기록을 '실제로' 저장했을 때만 +1.
        // 수정은 위에서 return, 다시 말하기(replaceExisting)는 '기존 기록 교체'이므로 제외한다.
        if !replaceExisting {
            freeSkyCounter?.increment()
            evaluateFreeLimitNotice()
        }
    }

    /// 30번째 무료 하늘을 저장하면 결과 카드에서 한 번만 안내한다. (PL-OBQXIP)
    private func evaluateFreeLimitNotice() {
        guard let counter = freeSkyCounter,
              let entitlement, !entitlement.isUnlocked,
              counter.count == counter.limit,
              !defaults.bool(forKey: AppSettings.Keys.hasShownFreeLimitNotice)
        else { return }
        reachedFreeLimitNotice = true
        defaults.set(true, forKey: AppSettings.Keys.hasShownFreeLimitNotice)
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

    // MARK: - 화면 자동 잠금 제어

    private func setIdleTimer(disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    // MARK: - 인터럽션 관찰 (전화 등 오디오 세션 인터럽션)

    /// 인터럽션 옵저버를 등록한다. 등록은 이 메서드가 반환하는 즉시 활성화되므로,
    /// 등록 직후 들어오는 인터럽션도 놓치지 않는다.
    private func startInterruptionObserver() {
        // 중복 등록 방지: 이미 등록돼 있으면 먼저 해제한다.
        // (녹음 재시작 등으로 startRecording이 다시 호출돼도 옵저버는 항상 1개만 유지)
        stopInterruptionObserver()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // 인터럽션 '시작' 유형만 처리한다.
            guard
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: raw),
                type == .began
            else { return }
            Task { @MainActor in
                await self?.handleInterruption()
            }
        }
    }

    private func stopInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    deinit {
        // ViewModel이 해제될 때 옵저버가 반드시 풀리도록 하는 최종 안전장치.
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 화면을 벗어날 때(onDisappear) 호출. 인터럽션 옵저버를 해제한다.
    func viewDidDisappear() {
        stopInterruptionObserver()
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
