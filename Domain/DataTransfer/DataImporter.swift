//
//  DataImporter.swift
//  BlueHour
//
//  가져오기 ZIP을 임시 폴더에 풀고 bluehour.json을 '끝까지' 검증한 뒤, 복원할 기록 목록을 돌려준다. (F-XXQNPA)
//  저장(DB 반영)은 하지 않는다. 검증까지만 책임지며, 실제 저장·롤백은 DataTransferController가 맡는다.
//  모르는 formatVersion·형식 오류·손상은 모두 DataTransferError.cannotImport 로 알린다.
//

import Foundation
import ZIPFoundation

/// 검증을 마친 가져오기 결과. tempDirectory는 음성 원본이 든 임시 폴더이며, 다 쓰면 cleanup으로 지운다.
struct ParsedImport: Sendable {
    let tempDirectory: URL
    let entries: [ParsedEntry]
}

/// 복원할 기록 하나. 음성이 ZIP에 실제로 있으면 audioSourceURL이 임시 경로를 가리킨다.
struct ParsedEntry: Sendable {
    let date: Date
    let createdAt: Date
    let updatedAt: Date
    let transcript: DiaryTranscript?
    let analysis: SkyAnalysis?
    /// ZIP recordings/ 안에 파일이 실제로 있을 때만 경로를 담는다. 없으면 목소리 없는 기록.
    let audioSourceURL: URL?
    let audioDuration: TimeInterval?
    let audioCreatedAt: Date?
}

struct DataImporter {

    /// ZIP을 풀고 bluehour.json을 검증해 복원할 기록 목록을 돌려준다.
    /// 실패하면 임시 폴더를 정리하고 DataTransferError.cannotImport 를 던진다.
    func read(zipURL: URL) throws -> ParsedImport {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: zipURL, to: tempDirectory)
        } catch {
            try? fileManager.removeItem(at: tempDirectory)
            throw DataTransferError.cannotImport
        }

        do {
            let parsed = try parse(tempDirectory: tempDirectory)
            return parsed
        } catch {
            // 검증 실패 → 아무것도 바꾸지 않았고, 임시 폴더만 지운다.
            try? fileManager.removeItem(at: tempDirectory)
            throw DataTransferError.cannotImport
        }
    }

    /// 임시 폴더를 정리한다(성공·실패 무관하게 호출 측에서 마지막에 부른다).
    func cleanup(_ parsed: ParsedImport) {
        try? FileManager.default.removeItem(at: parsed.tempDirectory)
    }

    // MARK: - 검증

    private func parse(tempDirectory: URL) throws -> ParsedImport {
        let fileManager = FileManager.default
        let jsonURL = tempDirectory.appendingPathComponent(DataTransfer.jsonFileName)

        guard fileManager.fileExists(atPath: jsonURL.path) else {
            throw DataTransferError.cannotImport
        }

        let data = try Data(contentsOf: jsonURL)
        let document = try DataTransfer.makeJSONDecoder().decode(ExportDocument.self, from: data)

        // 모르는 formatVersion은 거부한다.
        guard document.formatVersion == DataTransfer.currentFormatVersion else {
            throw DataTransferError.cannotImport
        }

        let recordingsDirectory = tempDirectory
            .appendingPathComponent(DataTransfer.recordingsFolderName, isDirectory: true)

        var parsedEntries: [ParsedEntry] = []
        for entry in document.entries {
            // analysis가 있는데 weatherType이 알 수 없는 값이면 형식 오류로 본다.
            var analysis: SkyAnalysis? = nil
            if let exportAnalysis = entry.analysis {
                guard let restored = exportAnalysis.makeAnalysis() else {
                    throw DataTransferError.cannotImport
                }
                analysis = restored
            }

            // JSON에 파일명이 있어도 ZIP에 실제 파일이 없으면 목소리 없는 기록으로 가져온다.
            var audioSourceURL: URL? = nil
            if let audioFileName = entry.audioFileName {
                let candidate = recordingsDirectory.appendingPathComponent(audioFileName)
                if fileManager.fileExists(atPath: candidate.path) {
                    audioSourceURL = candidate
                }
            }

            parsedEntries.append(
                ParsedEntry(
                    date: entry.date,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt,
                    transcript: entry.makeTranscript(),
                    analysis: analysis,
                    audioSourceURL: audioSourceURL,
                    audioDuration: audioSourceURL == nil ? nil : entry.audioDuration,
                    audioCreatedAt: audioSourceURL == nil ? nil : entry.audioCreatedAt
                )
            )
        }

        return ParsedImport(tempDirectory: tempDirectory, entries: parsedEntries)
    }
}
