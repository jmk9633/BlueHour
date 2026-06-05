//
//  DiaryRepositoryProtocol.swift
//  BlueHour
//
//  Created by 정문기 on 6/4/26.
//

import Foundation

protocol DiaryRepositoryProtocol: Sendable {
    func save(_ entry: DiaryEntry) async throws
    func update(_ entry: DiaryEntry) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws

    func fetch(id: UUID) async throws -> DiaryEntry?
    func fetchEntry(on date: Date) async throws -> DiaryEntry?
    func fetchEntries(in interval: DateInterval) async throws -> [DiaryEntry]
    func fetchAll() async throws -> [DiaryEntry]
}
