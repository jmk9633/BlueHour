//
//  DiaryRepository.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import Foundation
import SwiftData

@MainActor
final class DiaryRepository: DiaryRepositoryProtocol {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Write

    func save(_ entry: DiaryEntry) async throws {
        let sd = DiaryEntryMapper.toSD(entry)
        context.insert(sd)
        try context.save()
    }

    func update(_ entry: DiaryEntry) async throws {
        guard let sd = try fetchSD(id: entry.id) else {
            // 없으면 신규 저장으로 폴백
            try await save(entry)
            return
        }
        DiaryEntryMapper.apply(entry, to: sd)
        try context.save()
    }

    func delete(id: UUID) async throws {
        guard let sd = try fetchSD(id: id) else { return }
        context.delete(sd)
        try context.save()
    }

    func deleteAll() async throws {
        try context.delete(model: SDDiaryEntry.self)
        try context.save()
    }

    // MARK: - Read

    func fetch(id: UUID) async throws -> DiaryEntry? {
        try fetchSD(id: id).map(DiaryEntryMapper.toDomain)
    }

    func fetchEntry(on date: Date) async throws -> DiaryEntry? {
        let interval = Self.dayInterval(for: date)
        let lower = interval.start
        let upper = interval.end
        var descriptor = FetchDescriptor<SDDiaryEntry>(
            predicate: #Predicate { $0.date >= lower && $0.date < upper }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(DiaryEntryMapper.toDomain)
    }

    func fetchEntries(in interval: DateInterval) async throws -> [DiaryEntry] {
        let lower = interval.start
        let upper = interval.end
        let descriptor = FetchDescriptor<SDDiaryEntry>(
            predicate: #Predicate { $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try context.fetch(descriptor).map(DiaryEntryMapper.toDomain)
    }

    func fetchAll() async throws -> [DiaryEntry] {
        let descriptor = FetchDescriptor<SDDiaryEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map(DiaryEntryMapper.toDomain)
    }

    // MARK: - Private

    private func fetchSD(id: UUID) throws -> SDDiaryEntry? {
        var descriptor = FetchDescriptor<SDDiaryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func dayInterval(for date: Date) -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}
