//
//  SkyCalendarView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct SkyCalendarView: View {
    @Environment(\.di) private var di
    // 다크 모드에서 타일 밝기를 낮추는 검정 10% 덮개 판단용. (F-QMDQQQ)
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: SkyCalendarViewModel?
    @State private var selectedEntry: DiaryEntry?
    @State private var recordTarget: RecordTarget?
    /// 빈 날짜를 탭했을 때 '이 날의 하늘을 남길까요?' 확인을 거칠 대상 날짜
    @State private var pendingRecordDate: Date?
    /// 무료 한도 도달 시 구매 화면을 띄울지 여부
    @State private var showPurchase = false
    /// 구매 성공 후 바로 기록을 시작할 대상 날짜 (빈 과거 날짜 입구에서 막혔던 날)
    @State private var purchaseTargetDate: Date?

    // 연·월 휠 피커 상태
    @State private var showMonthPicker = false
    @State private var pickerYear = 0
    @State private var pickerMonth = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: BHMetrics.spacingS), count: 7)

    /// 빈 날짜를 탭해 기록 플로우로 진입할 때 넘길 대상 날짜 (시트용 Identifiable 래퍼)
    private struct RecordTarget: Identifiable {
        let date: Date
        var id: TimeInterval { date.timeIntervalSince1970 }
    }

    var body: some View {
        ZStack {
            Color.bhBackground.ignoresSafeArea()

            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = SkyCalendarViewModel(
                    repository: di.diaryRepository,
                    entitlement: di.purchaseController,
                    counter: di.freeSkyCounter
                )
                viewModel = vm
                await vm.load()
            }
        }
        // 탭을 다시 볼 때마다 최신 데이터로 새로고침 (저장 즉시 반영)
        .onAppear {
            if let viewModel {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                SkyDetailView(entry: entry) {
                    Task { await viewModel?.load() }
                }
            }
        }
        .sheet(item: $recordTarget) { target in
            // 오늘 플로우와 동일한 화면을 대상 날짜만 바꿔 재사용
            RecordFlowView(targetDate: target.date) {
                recordTarget = nil
                Task { await viewModel?.load() }
            }
        }
        .sheet(isPresented: $showMonthPicker) {
            if let viewModel {
                monthPickerSheet(viewModel)
            }
        }
        // 무료 한도 도달 시 구매 화면. 구매 성공 후 막혔던 날짜의 기록으로 바로 이어간다.
        .sheet(isPresented: $showPurchase) {
            PurchaseView(
                controller: di.purchaseController,
                analysisService: di.analysisService
            ) {
                if let date = purchaseTargetDate {
                    recordTarget = RecordTarget(date: date)
                }
                purchaseTargetDate = nil
                showPurchase = false
            }
        }
        // 빈 과거/오늘 날짜를 탭하면 먼저 확인을 거친 뒤 기록 플로우로 진입
        .confirmationDialog(
            "이 날의 하늘을 남길까요?",
            isPresented: Binding(
                get: { pendingRecordDate != nil },
                set: { if !$0 { pendingRecordDate = nil } }
            ),
            presenting: pendingRecordDate
        ) { date in
            Button("남기기") {
                recordTarget = RecordTarget(date: date)
                pendingRecordDate = nil
            }
            Button("취소", role: .cancel) {
                pendingRecordDate = nil
            }
        }
    }

    // 연·월 휠 피커 시트
    private func monthPickerSheet(_ viewModel: SkyCalendarViewModel) -> some View {
        VStack(spacing: BHMetrics.spacingL) {
            Text("연 · 월 선택")
                .font(.bhHeadline)
                .foregroundStyle(Color.bhTextPrimary)
                .padding(.top, BHMetrics.spacingL)

            HStack(spacing: 0) {
                Picker("연도", selection: $pickerYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text(String(year) + "년").tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)월").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }

            Button("확인") {
                Task { await viewModel.goTo(year: pickerYear, month: pickerMonth) }
                showMonthPicker = false
            }
            .buttonStyle(.bhPrimary)
        }
        .padding(BHMetrics.screenPadding)
        .presentationDetents([.medium])
        .background(Color.bhBackground)
    }

    /// 휠 피커 연도 범위: 2020년부터 올해까지 (미래 기록은 없으므로 올해까지)
    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: BlueHourClock.now())
        return Array(2020...max(current, 2020))
    }

    private func content(_ viewModel: SkyCalendarViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BHMetrics.spacingL) {

                // 월 타이틀 + 이동
                HStack {
                    Button {
                        Task { await viewModel.goToPreviousMonth() }
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()

                    Button {
                        pickerYear = viewModel.year
                        pickerMonth = viewModel.month
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: BHMetrics.spacingS) {
                            Text(viewModel.monthTitle)
                                .font(.bhHeadline)
                                .foregroundStyle(Color.bhTextPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(Color.bhTextSecondary)
                        }
                    }

                    Spacer()

                    Button {
                        Task { await viewModel.goToNextMonth() }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundStyle(Color.bhTextSecondary)

                // 날씨별 요약
                if !viewModel.weatherCounts.isEmpty {
                    VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                        ForEach(viewModel.weatherCounts, id: \.type) { item in
                            HStack(spacing: BHMetrics.spacingM) {
                                Circle()
                                    .fill(item.type.tileColor)
                                    .frame(width: 12, height: 12)
                                Text(item.type.displayName)
                                    .font(.bhBody)
                                    .foregroundStyle(Color.bhTextPrimary)
                                Spacer()
                                Text("\(item.count)일")
                                    .font(.bhCaption)
                                    .foregroundStyle(Color.bhTextSecondary)
                            }
                        }
                    }
                    .padding(BHMetrics.spacingL)
                    .background(
                        RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous)
                            .fill(Color.bhSurface)
                    )
                }

                // 하늘 조각 그리드
                LazyVGrid(columns: columns, spacing: BHMetrics.spacingS) {
                    ForEach(viewModel.daysInCurrentMonth(), id: \.self) { day in
                        skyTile(for: day, viewModel: viewModel)
                    }
                }

                if viewModel.weatherCounts.isEmpty && !viewModel.isLoading {
                    Text("이 달에는 아직 하늘이 없어요.")
                        .font(.bhCaption)
                        .foregroundStyle(Color.bhTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, BHMetrics.spacingXL)
                }
            }
            .padding(BHMetrics.screenPadding)
        }
    }

    private func skyTile(for day: Date, viewModel: SkyCalendarViewModel) -> some View {
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: day)
        // 미래/오늘 판단은 새벽 4시 경계(BlueHourCalendar)를 따른다
        let isFuture = viewModel.isFuture(normalized)
        let entry = viewModel.entry(for: normalized)
        let sky = viewModel.skyByDay[normalized]
        // 기록은 있는데 아직 하늘이 그려지지 않은 날
        let isUndrawn = entry != nil && sky == nil

        return tileBackground(sky: sky)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: BHMetrics.cornerS, style: .continuous))
            // 미래 날짜는 흐리게 표시해 비활성임을 알린다
            .opacity(isFuture ? 0.35 : 1)
            .overlay {
                // '아직 그려지지 않은 하늘'은 작은 점으로 빈 날과 구분한다
                if isUndrawn {
                    Circle()
                        .fill(Color.bhTextSecondary)
                        .frame(width: 5, height: 5)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.bhTextSecondary.opacity(0.7))
                    .padding(3)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let entry {
                    // 기록이 있는 날(하늘 유무와 무관) → 그날의 상세 보기
                    selectedEntry = entry
                } else if !isFuture {
                    // 빈 과거/오늘 날짜 → 무료 한도 확인(확인 알림보다 먼저) 후 기록 플로우 진입
                    Task {
                        if await viewModel.canStartNewEntry() {
                            pendingRecordDate = normalized
                        } else {
                            purchaseTargetDate = normalized
                            showPurchase = true
                        }
                    }
                }
                // 미래 날짜 → 반응 없음
            }
    }

    /// 타일 배경. 하늘이 있으면 Warm Ivory 바탕 + 날씨색(+다크 10% 덮개),
    /// 없으면(빈 날·아직 그려지지 않은 하늘) 화면 요소이므로 bhSurface.
    @ViewBuilder
    private func tileBackground(sky: SkyAnalysis?) -> some View {
        if let sky {
            ZStack {
                // 투명도 있는 날씨색이 화면 배경과 섞이지 않도록 Ivory 바탕을 먼저 깐다.
                Color.bhWarmIvory
                sky.weatherType.tileColor
                if colorScheme == .dark {
                    Color.black.opacity(0.10)
                }
            }
        } else {
            Color.bhSurface
        }
    }
}
