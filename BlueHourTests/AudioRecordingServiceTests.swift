//
//  AudioRecordingServiceTests.swift
//  BlueHourTests
//
//  전체 기록 삭제 시 음성 파일도 함께 지워지는지 검증 (F-MRTPNE).
//

import XCTest
@testable import BlueHour

final class AudioRecordingServiceTests: XCTestCase {

    private var recordingsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Recordings", isDirectory: true)
    }

    func test_deleteAllRecordings_emptiesDirectory() async throws {
        // AudioRecordingService는 init에서 Documents/Recordings를 만든다.
        let service = AudioRecordingService()
        let fileManager = FileManager.default

        // 더미 음성 파일 몇 개를 심어 둔다.
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        for _ in 0..<3 {
            let file = recordingsDirectory.appendingPathComponent("dummy-\(UUID().uuidString).m4a")
            try Data([0x00, 0x01, 0x02]).write(to: file)
        }

        let before = try fileManager.contentsOfDirectory(atPath: recordingsDirectory.path)
        XCTAssertFalse(before.isEmpty, "사전 조건: 더미 파일이 있어야 합니다.")

        try await service.deleteAllRecordings()

        let after = try fileManager.contentsOfDirectory(atPath: recordingsDirectory.path)
        XCTAssertTrue(after.isEmpty, "deleteAllRecordings() 후에도 파일이 남아 있습니다: \(after)")
    }
}
