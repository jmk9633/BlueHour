//
//  AudioRecordingServiceProtocol.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

enum AudioRecordingError: Error, Sendable {
    case permissionDenied
    case sessionSetupFailed
    case recordingFailed
    case noActiveRecording
}

protocol AudioRecordingServiceProtocol: Sendable {
    /// 마이크 권한 요청
    func requestPermission() async -> Bool

    /// 녹음 시작. 저장될 파일명 반환
    func startRecording() async throws -> String

    /// 녹음 일시중지
    func pauseRecording() async

    /// 일시중지한 녹음 이어서 시작
    func resumeRecording() async throws

    /// 녹음 정지. (파일명, 길이) 반환
    func stopRecording() async throws -> (fileName: String, duration: TimeInterval)

    /// 녹음 취소 및 파일 삭제
    func cancelRecording() async

    /// 음성 파일 삭제
    func deleteRecording(fileName: String) async throws
}
