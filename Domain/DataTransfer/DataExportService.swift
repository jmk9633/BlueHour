//
//  DataExportService.swift
//  BlueHour
//
//  내보낼 기록으로 ZIP 파일 하나(bluehour.json + 블루아워_기록.txt + recordings/)를 만든다. (F-NJSTGI)
//  무거운 파일 I/O는 Task.detached에서 돌려 메인 스레드를 막지 않는다.
//

import Foundation
import ZIPFoundation

struct DataExportService {

    /// 내보내기에 담을 음성 파일 하나(ZIP 내부 이름과 원본 경로).
    struct AudioSource: Sendable {
        let nameInZip: String   // "UUID.m4a" (recordings/ 아래 이름)
        let sourceURL: URL
    }

    /// ZIP 파일을 임시 폴더에 만들고 그 경로를 돌려준다. (공유 시트가 닫히면 호출 측이 정리한다)
    /// - Note: 전체 작업을 백그라운드에서 수행한다.
    func makeExportFile(
        document: ExportDocument,
        audioSources: [AudioSource]
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try Self.writeZip(document: document, audioSources: audioSources)
        }.value
    }

    // MARK: - 실제 작성 (백그라운드)

    private static func writeZip(
        document: ExportDocument,
        audioSources: [AudioSource]
    ) throws -> URL {
        let fileManager = FileManager.default

        // 임시 작업 폴더
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDirectory) }

        let zipURL = workDirectory.appendingPathComponent(DataTransfer.exportFileName())

        let archive = try Archive(url: zipURL, accessMode: .create)

        // bluehour.json
        let jsonData = try DataTransfer.makeJSONEncoder().encode(document)
        try archive.addEntry(
            with: DataTransfer.jsonFileName,
            type: .file,
            uncompressedSize: Int64(jsonData.count),
            provider: { position, size in
                let start = Int(position)
                return jsonData.subdata(in: start ..< start + size)
            }
        )

        // 블루아워_기록.txt
        let readableText = ReadableTextBuilder.build(entries: document.entries)
        let textData = Data(readableText.utf8)
        try archive.addEntry(
            with: DataTransfer.readableTextFileName,
            type: .file,
            uncompressedSize: Int64(textData.count),
            provider: { position, size in
                let start = Int(position)
                return textData.subdata(in: start ..< start + size)
            }
        )

        // recordings/*.m4a
        for source in audioSources where fileManager.fileExists(atPath: source.sourceURL.path) {
            try archive.addEntry(
                with: "\(DataTransfer.recordingsFolderName)/\(source.nameInZip)",
                fileURL: source.sourceURL
            )
        }

        // 작업 폴더가 defer로 지워지므로, 호출 측이 쓸 수 있게 별도 위치로 옮긴다.
        let finalURL = fileManager.temporaryDirectory
            .appendingPathComponent(DataTransfer.exportFileName())
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        try fileManager.moveItem(at: zipURL, to: finalURL)
        return finalURL
    }
}
