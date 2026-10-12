//
//  AudioRecordingService.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import AVFoundation

actor AudioRecordingService: AudioRecordingServiceProtocol {

    private var recorder: AVAudioRecorder?
    private var currentFileName: String?

    // 음성 파일을 저장할 폴더 (앱 전용 Documents/Recordings)
    private let recordingsDirectory: URL

    /// 저장 폴더를 바꿔 끼울 수 있게 한다(테스트는 임시 폴더를 쓴다). 기본값은 Documents/Recordings.
    init(recordingsDirectory: URL? = nil) {
        if let recordingsDirectory {
            self.recordingsDirectory = recordingsDirectory
        } else {
            let documents = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            self.recordingsDirectory = documents.appendingPathComponent("Recordings", isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: self.recordingsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - 권한

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 녹음 시작

    func startRecording() async throws -> String {
        // 오디오 세션 준비
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            throw AudioRecordingError.sessionSetupFailed
        }

        // 파일명 생성 (UUID로 충돌 방지)
        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        // 녹음 포맷 설정 (AAC, 44.1kHz, 모노)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            guard recorder.record() else {
                throw AudioRecordingError.recordingFailed
            }
            self.recorder = recorder
            self.currentFileName = fileName
            return fileName
        } catch {
            throw AudioRecordingError.recordingFailed
        }
    }

    // MARK: - 녹음 일시중지 / 이어서 시작

    func pauseRecording() async {
        recorder?.pause()
    }

    func resumeRecording() async throws {
        guard let recorder else {
            throw AudioRecordingError.noActiveRecording
        }
        guard recorder.record() else {
            throw AudioRecordingError.recordingFailed
        }
    }

    // MARK: - 녹음 정지

    func stopRecording() async throws -> (fileName: String, duration: TimeInterval) {
        guard let recorder, let fileName = currentFileName else {
            throw AudioRecordingError.noActiveRecording
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        self.currentFileName = nil

        // 세션 비활성화 (배터리/다른 앱 배려)
        try? AVAudioSession.sharedInstance().setActive(false)

        return (fileName, duration)
    }

    // MARK: - 녹음 취소

    func cancelRecording() async {
        guard let recorder, let fileName = currentFileName else { return }
        recorder.stop()
        recorder.deleteRecording()
        self.recorder = nil
        self.currentFileName = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        // 혹시 남은 파일 정리
        try? deleteFile(fileName: fileName)
    }

    // MARK: - 파일 삭제

    func deleteRecording(fileName: String) async throws {
        try deleteFile(fileName: fileName)
    }

    func deleteAllRecordings() async throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: nil
        )
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func deleteFile(fileName: String) throws {
        let url = recordingsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// 파일명으로 전체 경로 반환 (음성→글자 변환 일꾼이 사용)
    func fileURL(for fileName: String) -> URL {
        recordingsDirectory.appendingPathComponent(fileName)
    }
}

// MARK: - RecordingFileStoring (내보내기/가져오기용 파일 조작)

extension AudioRecordingService: RecordingFileStoring {

    /// 외부 파일을 Recordings 폴더로 새 UUID 이름으로 복사한다. (가져온 음성은 새 이름으로 보관)
    func copyIntoRecordings(from sourceURL: URL) async throws -> String {
        let fileName = "\(UUID().uuidString).m4a"
        let destination = recordingsDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return fileName
    }

    /// Recordings의 파일을 임시 보관 폴더로 옮긴다. 파일이 없으면 nil.
    func moveOutOfRecordings(fileName: String, to directory: URL) async throws -> URL? {
        let source = recordingsDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
        return destination
    }

    /// 임시 보관 폴더의 파일을 원래 파일명으로 Recordings에 되돌린다.
    func restoreIntoRecordings(from url: URL, fileName: String) async throws {
        let destination = recordingsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: url, to: destination)
    }

    /// Recordings의 파일을 삭제한다.
    func deleteFromRecordings(fileName: String) async throws {
        try deleteFile(fileName: fileName)
    }

    /// Recordings에 해당 파일이 있는지.
    func fileExists(fileName: String) async -> Bool {
        let url = recordingsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
