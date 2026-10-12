//
//  RecordingFileStoring.swift
//  BlueHour
//
//  음성 파일(Documents/Recordings)에 대한 파일 단위 조작의 추상화.
//  데이터 내보내기/가져오기가 음성 파일을 찾고·복사하고·임시 보관·복원하는 데 쓴다.
//  녹음 자체(AudioRecordingServiceProtocol)와는 관심사를 분리한다.
//

import Foundation

protocol RecordingFileStoring: Sendable {
    /// Recordings 폴더 안에서 파일명에 해당하는 경로.
    func fileURL(for fileName: String) async -> URL

    /// 외부 파일을 Recordings 폴더로 새 UUID 이름으로 복사하고, 새 파일명을 돌려준다.
    func copyIntoRecordings(from sourceURL: URL) async throws -> String

    /// Recordings의 파일을 임시 보관 폴더로 옮긴다(복원 대비). 파일이 없으면 nil.
    func moveOutOfRecordings(fileName: String, to directory: URL) async throws -> URL?

    /// 임시 보관 폴더의 파일을 원래 파일명으로 Recordings에 되돌린다.
    func restoreIntoRecordings(from url: URL, fileName: String) async throws

    /// Recordings의 파일을 삭제한다.
    func deleteFromRecordings(fileName: String) async throws

    /// Recordings에 해당 파일이 있는지.
    func fileExists(fileName: String) async -> Bool
}
