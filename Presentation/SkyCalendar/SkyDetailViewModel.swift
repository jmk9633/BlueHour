//
//  SkyDetailViewModel.swift
//  BlueHour
//
//  하늘 상세 시트의 상태와 기록 관리 동작(삭제 / 목소리 지우기 / 재조회)을 담당한다.
//  (F-MDQVXP 삭제, S-OZKPTH 목소리 지우기)
//

import Foundation
import Observation

@MainActor
@Observable
final class SkyDetailViewModel {

    private(set) var entry: DiaryEntry

    private let repository: DiaryRepositoryProtocol
    private let audioService: AudioRecordingServiceProtocol

    init(
        entry: DiaryEntry,
        repository: DiaryRepositoryProtocol,
        audioService: AudioRecordingServiceProtocol
    ) {
        self.entry = entry
        self.repository = repository
        self.audioService = audioService
    }

    /// 이 기록에 다시 들을 수 있는 목소리가 있는지.
    var hasVoice: Bool {
        entry.recording != nil
    }

    // MARK: - 삭제 (F-MDQVXP)

    /// 기록을 영구 삭제한다. 연결된 음성 파일도 함께 지운다.
    func deleteEntry() async {
        if let fileName = entry.recording?.fileName {
            try? await audioService.deleteRecording(fileName: fileName)
        }
        try? await repository.delete(id: entry.id)
    }

    // MARK: - 목소리 지우기 (S-OZKPTH)

    /// 이 기록의 음성 파일만 삭제한다. 하늘(analysis)과 글(transcript)은 그대로 둔다.
    func eraseVoice() async {
        guard let fileName = entry.recording?.fileName else { return }
        try? await audioService.deleteRecording(fileName: fileName)

        var updated = entry
        updated.recording = nil
        updated.updatedAt = .now
        try? await repository.update(updated)
        entry = updated
    }

    // MARK: - 재조회

    /// 수정·다시 말하기 후 최신 상태를 다시 읽어 반영한다.
    /// 다시 말하기는 기록 id가 바뀔 수 있으므로 날짜 기준으로 조회한다.
    func reload() async {
        if let refreshed = try? await repository.fetchEntry(on: entry.date) {
            entry = refreshed
        }
    }
}
