//
//  DataTransferController.swift
//  BlueHour
//
//  데이터 내보내기(F-NJSTGI)·기록 가져오기(F-XXQNPA)의 화면용 상태와 흐름을 담는다.
//  - 내보내기: 기록으로 ZIP을 만들어 공유 시트로 넘긴다.
//  - 가져오기: ZIP을 검증한 뒤, 겹치는 날짜가 있으면 한 번 묻고, 저장은 되돌릴 수 있게 수행한다.
//    가져오기는 무료 카운트를 늘리지 않고, 가져온 음성은 현재 저장 방식 설정과 무관하게 보관한다.
//

import Foundation
import Observation

@MainActor
@Observable
final class DataTransferController {

    // MARK: - 내보내기 화면 상태

    /// 저장된 기록이 1개 이상인지(내보내기 버튼 활성화 판단).
    private(set) var canExport = false
    /// 목소리가 남은 기록이 하나라도 있는지('목소리도 함께 담기' 선택지 노출 판단).
    private(set) var hasAnyVoice = false
    /// '목소리도 함께 담기'(기본 켜짐).
    var includeVoice = true

    // MARK: - 가져오기 화면 상태

    /// 겹치는 날짜 수. nil이 아니면 '바꾸기/기존 하늘 유지'를 한 번 묻는다.
    var overlapPromptCount: Int?
    /// 완료/실패 안내 문구. 표시 후 nil로 지운다.
    var resultMessage: String?

    /// 테스트·후처리용 마지막 가져오기 결과.
    enum ImportOutcome: Equatable {
        case imported(days: Int)
        case cannotImport
    }
    private(set) var lastImportOutcome: ImportOutcome?

    /// 겹침 확인을 기다리는 동안 보관하는 검증 결과.
    private var pendingParsed: ParsedImport?

    // MARK: - 의존성

    private let repository: DiaryRepositoryProtocol
    private let fileStore: RecordingFileStoring
    private let exportService: DataExportService
    private let importer: DataImporter
    private let pendingAnalyzer: PendingSkyAnalyzer?
    private let reminderController: NightReminderController?
    private let calendar: Calendar

    init(
        repository: DiaryRepositoryProtocol,
        fileStore: RecordingFileStoring,
        pendingAnalyzer: PendingSkyAnalyzer? = nil,
        reminderController: NightReminderController? = nil,
        exportService: DataExportService = DataExportService(),
        importer: DataImporter = DataImporter(),
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.fileStore = fileStore
        self.pendingAnalyzer = pendingAnalyzer
        self.reminderController = reminderController
        self.exportService = exportService
        self.importer = importer
        self.calendar = calendar
    }

    // MARK: - 내보내기

    /// 내보내기 버튼 활성화·'목소리 함께 담기' 노출 여부를 최신 상태로 갱신한다.
    func refreshExportAvailability() async {
        let entries = (try? await repository.fetchAll()) ?? []
        canExport = !entries.isEmpty
        hasAnyVoice = entries.contains { $0.recording != nil }
    }

    /// ZIP 파일을 만들어 공유할 임시 경로를 돌려준다. 기록이 없으면 nil.
    func makeExportFile() async -> URL? {
        let entries = (try? await repository.fetchAll()) ?? []
        guard !entries.isEmpty else { return nil }

        let sorted = entries.sorted { $0.date < $1.date }
        let exportEntries = sorted.map { ExportEntry(entry: $0, includeVoice: includeVoice) }

        var audioSources: [DataExportService.AudioSource] = []
        if includeVoice {
            for entry in sorted {
                guard let fileName = entry.recording?.fileName else { continue }
                let url = await fileStore.fileURL(for: fileName)
                audioSources.append(.init(nameInZip: fileName, sourceURL: url))
            }
        }

        let document = ExportDocument(
            formatVersion: DataTransfer.currentFormatVersion,
            appVersion: Self.appVersion,
            exportedAt: BlueHourClock.now(),
            entries: exportEntries
        )
        return try? await exportService.makeExportFile(document: document, audioSources: audioSources)
    }

    /// 공유 시트가 닫히면 임시 ZIP을 정리한다.
    func cleanupExportFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 가져오기

    /// 파일 선택기가 고른 ZIP을 검증한다. 겹치는 날짜가 있으면 확인을 띄우고, 없으면 바로 저장한다.
    func beginImport(from pickedURL: URL) async {
        let importer = self.importer
        let needsScope = pickedURL.startAccessingSecurityScopedResource()
        let result: ParsedImport? = await Task.detached(priority: .userInitiated) {
            try? importer.read(zipURL: pickedURL)
        }.value
        if needsScope { pickedURL.stopAccessingSecurityScopedResource() }

        guard let parsed = result else {
            finishFailure()
            return
        }

        let existing = (try? await repository.fetchAll()) ?? []
        let existingDays = Set(existing.map { startOfDay($0.date) })
        let parsedDays = Set(parsed.entries.map { startOfDay($0.date) })
        let overlap = parsedDays.intersection(existingDays)

        if overlap.isEmpty {
            await commit(parsed: parsed, overwrite: false)
        } else {
            pendingParsed = parsed
            overlapPromptCount = overlap.count
        }
    }

    /// 겹침 확인에 대한 사용자의 선택. overwrite=true는 [바꾸기], false는 [기존 하늘 유지].
    func resolveOverlap(overwrite: Bool) async {
        guard let parsed = pendingParsed else { return }
        await commit(parsed: parsed, overwrite: overwrite)
    }

    // MARK: - 저장 (되돌릴 수 있게)

    /// 백업·롤백에 쓰는 교체 대상 기록 묶음.
    private struct Backup {
        let entry: DiaryEntry
        let holdingURL: URL?
        let fileName: String?
    }

    private func commit(parsed: ParsedImport, overwrite: Bool) async {
        defer {
            importer.cleanup(parsed)
            pendingParsed = nil
            overlapPromptCount = nil
        }

        // 기존 기록을 날짜별로(하루 1개) 모은다.
        let existing = (try? await repository.fetchAll()) ?? []
        var existingByDay: [Date: DiaryEntry] = [:]
        for entry in existing {
            existingByDay[startOfDay(entry.date)] = entry
        }

        // 가져올 대상과 (바꾸기 시) 교체될 기존 기록을 가른다.
        var toImport: [ParsedEntry] = []
        var toReplace: [DiaryEntry] = []
        for entry in parsed.entries {
            let day = startOfDay(entry.date)
            if let old = existingByDay[day] {
                if overwrite {
                    toImport.append(entry)
                    toReplace.append(old)
                }
                // [기존 하늘 유지] → 겹치는 날짜는 건너뛴다.
            } else {
                toImport.append(entry)
            }
        }

        // 교체될 기존 음성을 잠시 보관할 폴더(복원 대비).
        let holding = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-holding-\(UUID().uuidString)", isDirectory: true)

        var backups: [Backup] = []
        var addedIDs: [UUID] = []
        var copiedFileNames: [String] = []

        do {
            // PHASE 1 — 교체될 기존 기록을 메모리에 백업하고, 음성은 임시 폴더로 옮긴 뒤 삭제한다.
            // 이 시점 이후 겹치는 날짜에는 기록이 하나도 없다(같은 날짜 기록이 두 개 공존하지 않음).
            for old in toReplace {
                var movedURL: URL?
                if let fileName = old.recording?.fileName {
                    movedURL = try await fileStore.moveOutOfRecordings(fileName: fileName, to: holding)
                }
                try await repository.delete(id: old.id)
                backups.append(Backup(entry: old, holdingURL: movedURL, fileName: old.recording?.fileName))
            }

            // PHASE 2 — 가져온 기록을 추가한다. 음성은 새 UUID로 복사해 연결한다.
            for parsedEntry in toImport {
                var recording: VoiceRecording?
                if let source = parsedEntry.audioSourceURL {
                    let newName = try await fileStore.copyIntoRecordings(from: source)
                    copiedFileNames.append(newName)
                    recording = VoiceRecording(
                        fileName: newName,
                        duration: parsedEntry.audioDuration ?? 0,
                        createdAt: parsedEntry.audioCreatedAt ?? parsedEntry.createdAt
                    )
                }
                let entry = DiaryEntry(
                    date: parsedEntry.date,
                    recording: recording,
                    transcript: parsedEntry.transcript,
                    analysis: parsedEntry.analysis,
                    createdAt: parsedEntry.createdAt,
                    updatedAt: parsedEntry.updatedAt
                )
                try await repository.save(entry)
                addedIDs.append(entry.id)
            }
        } catch {
            // ROLLBACK — 이번에 추가한 기록·복사한 음성을 지우고, 백업한 기존 기록과 음성을 원래대로 복원한다.
            for id in addedIDs { try? await repository.delete(id: id) }
            for fileName in copiedFileNames { try? await fileStore.deleteFromRecordings(fileName: fileName) }
            for backup in backups {
                if let url = backup.holdingURL, let fileName = backup.fileName {
                    try? await fileStore.restoreIntoRecordings(from: url, fileName: fileName)
                }
                try? await repository.save(backup.entry)
            }
            try? FileManager.default.removeItem(at: holding)
            finishFailure()
            return
        }

        // SUCCESS — 교체된 옛 음성(임시 보관본)을 영구 삭제한다.
        try? FileManager.default.removeItem(at: holding)

        let dayCount = Set(toImport.map { startOfDay($0.date) }).count
        lastImportOutcome = .imported(days: dayCount)
        resultMessage = "\(dayCount)일의 하늘을 가져왔어요."

        // 달력은 탭을 다시 볼 때 자동 새로고침된다. 자동 분석과 밤 리마인더만 다시 맞춘다.
        await pendingAnalyzer?.run()
        await reminderController?.reschedule()
    }

    // MARK: - 내부

    private func finishFailure() {
        lastImportOutcome = .cannotImport
        resultMessage = "이 파일은 가져올 수 없어요."
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
}
