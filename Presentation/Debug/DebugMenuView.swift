//
//  DebugMenuView.swift
//  BlueHour
//
//  출시 전 테스트용 개발자 도구 화면. DEBUG 빌드에만 포함된다.
//  실제 기능 코드를 바꾸지 않고, 주입된 서비스·공용 시계·DebugSettings를 통해 상태를 조작한다.
//  (개발용 화면이라 Manyfast 문구 규칙 적용 제외)
//

#if DEBUG
import SwiftUI
import UserNotifications

struct DebugMenuView: View {
    @Environment(\.di) private var di
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = DebugSettings.shared

    @State private var message: String?
    @State private var pending: [PendingReminder] = []
    @State private var shareItem: ShareURL?
    @State private var showResetConfirm = false

    private struct PendingReminder: Identifiable {
        let id: String
        let date: Date?
        let body: String
    }
    private struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        List {
            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }

            forcingSection
            freeCountSection
            seedSection
            todaySection
            aiSection
            speechSection
            clockSection
            resetSeenSection
            reminderSection
            zipSection
            wipeSection
        }
        .navigationTitle("개발자 도구")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(fileURL: item.url) { shareItem = nil }
        }
        .alert("전체 초기화", isPresented: $showResetConfirm) {
            Button("취소", role: .cancel) {}
            Button("초기화", role: .destructive) { Task { await wipeEverything() } }
        } message: {
            Text("기록·음성·설정·키체인 카운트·예약 알림을 모두 지웁니다. 끝나면 앱을 다시 실행해 주세요.")
        }
    }

    // MARK: - 강제 설정 되돌리기 (상단)

    private var forcingSection: some View {
        Section {
            Button("강제 설정 모두 실제로 되돌리기") {
                settings.resetAllForcing()
                show("강제 설정을 모두 실제로 되돌렸어요.")
            }
            .disabled(!settings.isAnyForcingActive)
        } footer: {
            Text(settings.isAnyForcingActive ? "강제 중인 설정이 있어요." : "모두 실제 설정을 따르는 중.")
        }
    }

    // MARK: - 1. 무료 카운트

    private var freeCountSection: some View {
        Section("무료 카운트") {
            HStack {
                Text("현재")
                Spacer()
                Text("\(di.freeSkyCounter.count) / \(di.freeSkyCounter.limit)")
                    .foregroundStyle(.secondary)
            }
            Button("0으로") { setFreeCount(0) }
            Button("29로") { setFreeCount(29) }
            Button("30으로") { setFreeCount(30) }
            Button("키체인 카운트 초기화", role: .destructive) {
                KeychainFreeSkyCountStore().debugDeleteStored()
                di.freeSkyCounter.debugSetCount(0)
                show("키체인 카운트를 초기화했어요.")
            }
        }
    }

    // MARK: - 2. 샘플 기록

    private var seedSection: some View {
        Section("샘플 기록") {
            ForEach(DebugSeedKind.allCases, id: \.self) { kind in
                Button(kind.label) { seed(kind) }
            }
        }
    }

    // MARK: - 3. 오늘 기록

    private var todaySection: some View {
        Section("오늘 기록") {
            Button("오늘 기록 만들기") { makeToday() }
            Button("오늘 기록 지우기", role: .destructive) { deleteToday() }
        }
    }

    // MARK: - 4. AI 상태

    private var aiSection: some View {
        Section("AI 상태 강제") {
            Picker("상태", selection: $settings.aiState) {
                ForEach(DebugSettings.AIState.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker("응답", selection: $settings.aiResponse) {
                ForEach(DebugSettings.AIResponse.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        }
    }

    // MARK: - 6. 음성 인식

    private var speechSection: some View {
        Section("음성 인식 강제") {
            Picker("모드", selection: $settings.speechMode) {
                ForEach(DebugSettings.SpeechMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        }
    }

    // MARK: - 7. 현재 시각

    private var clockSection: some View {
        Section {
            Toggle("시각 오버라이드", isOn: clockToggle)
            if settings.clockOffset != nil {
                DatePicker("현재 시각", selection: clockDate)
                Button("실제 시각으로") {
                    settings.clearClock()
                    show("실제 시각으로 되돌렸어요.")
                }
            }
        } header: {
            Text("현재 시각")
        } footer: {
            Text("적용 시각: \(settings.effectiveNow.formatted(date: .abbreviated, time: .standard)). 일부 화면은 다시 들어가야 반영돼요.")
        }
    }

    // MARK: - 8. 다시 보기 초기화

    private var resetSeenSection: some View {
        Section("다시 보기 초기화") {
            Button("첫 실행 안내 (재실행 필요)") {
                set(false, AppSettings.Keys.hasCompletedOnboarding)
                show("첫 실행 안내를 초기화했어요. 앱을 다시 실행하면 보여요.")
            }
            Button("리마인더 제안") {
                set(false, AppSettings.Keys.hasShownReminderPrompt)
                show("리마인더 제안을 초기화했어요.")
            }
            Button("30번째 안내") {
                set(false, AppSettings.Keys.hasShownFreeLimitNotice)
                show("30번째 안내를 초기화했어요.")
            }
        }
    }

    // MARK: - 9. 리마인더

    private var reminderSection: some View {
        Section("리마인더") {
            Button("1분 뒤 테스트 알림") { scheduleTestReminder() }
            Button("현재 예약 목록 보기") { Task { await loadPending() } }
            if pending.isEmpty {
                Text("예약 없음").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(pending) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.id).font(.caption).foregroundStyle(.secondary)
                        Text(item.date?.formatted(date: .abbreviated, time: .shortened) ?? "시각 미정")
                            .font(.caption2)
                        Text(item.body).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 10. 샘플 ZIP

    private var zipSection: some View {
        Section {
            ForEach(DebugZipKind.allCases, id: \.self) { kind in
                Button("ZIP 공유: \(kind.label)") { shareZip(kind) }
            }
        } header: {
            Text("가져오기용 샘플 ZIP")
        } footer: {
            Text("공유 시트에서 '파일에 저장'으로 내보낸 뒤, 나 탭 ▸ 기록 가져오기로 불러오세요.")
        }
    }

    // MARK: - 11. 전체 초기화

    private var wipeSection: some View {
        Section {
            Button("전체 초기화", role: .destructive) { showResetConfirm = true }
        }
    }

    // MARK: - 동작

    private func setFreeCount(_ n: Int) {
        di.freeSkyCounter.debugSetCount(n)
        show("무료 카운트를 \(n)으로 맞췄어요.")
    }

    private func seed(_ kind: DebugSeedKind) {
        Task {
            if let result = try? await DebugSampleBuilder.seed(kind, into: di) {
                show("\(kind.label): \(result.inserted)개 넣음, \(result.skipped)개 건너뜀.")
            } else {
                show("\(kind.label): 넣지 못했어요.")
            }
        }
    }

    private func makeToday() {
        Task {
            let today = BlueHourCalendar.startOfLogicalDay(for: BlueHourClock.now())
            if (try? await di.diaryRepository.fetchEntry(on: today)) != nil {
                show("오늘 기록이 이미 있어요(건너뜀).")
                return
            }
            let entry = DebugSampleBuilder.makeEntry(date: today, weather: .partlyCloudy)
            try? await di.diaryRepository.save(entry)
            await di.nightReminderController.reschedule()
            show("오늘 기록을 만들었어요.")
        }
    }

    private func deleteToday() {
        Task {
            let today = BlueHourCalendar.startOfLogicalDay(for: BlueHourClock.now())
            if let entry = try? await di.diaryRepository.fetchEntry(on: today) {
                try? await di.diaryRepository.delete(id: entry.id)
                await di.nightReminderController.reschedule()
                show("오늘 기록을 지웠어요.")
            } else {
                show("오늘 기록이 없어요.")
            }
        }
    }

    private func scheduleTestReminder() {
        Task {
            let center = UNUserNotificationCenter.current()
            if await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false {
                let content = UNMutableNotificationContent()
                content.body = NightReminderScheduler.messages[0]
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "debug-test-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
                show("1분 뒤 테스트 알림을 예약했어요.")
            } else {
                show("알림 권한이 없어요.")
            }
        }
    }

    private func loadPending() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        pending = requests.map { req in
            let date = (req.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (req.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
            return PendingReminder(id: req.identifier, date: date, body: req.content.body)
        }
        .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        if pending.isEmpty { show("예약된 알림이 없어요.") }
    }

    private func shareZip(_ kind: DebugZipKind) {
        do {
            let url = try DebugSampleBuilder.makeSampleZip(kind)
            shareItem = ShareURL(url: url)
        } catch {
            show("ZIP을 만들지 못했어요.")
        }
    }

    private func wipeEverything() async {
        try? await di.diaryRepository.deleteAll()
        try? await di.audioService.deleteAllRecordings()
        KeychainFreeSkyCountStore().debugDeleteStored()
        di.freeSkyCounter.debugSetCount(0)
        UNUserNotificationCenterCleaner.removeAllPending()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        settings.resetAllForcing()
        show("전체 초기화 완료. 앱을 다시 실행해 주세요.")
    }

    // MARK: - 보조

    private func show(_ text: String) { message = text }

    private func set(_ value: Bool, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private var clockToggle: Binding<Bool> {
        Binding(
            get: { settings.clockOffset != nil },
            set: { on in
                if on { settings.setClock(to: Date()) } else { settings.clearClock() }
            }
        )
    }

    private var clockDate: Binding<Date> {
        Binding(
            get: { settings.effectiveNow },
            set: { settings.setClock(to: $0) }
        )
    }
}
#endif
