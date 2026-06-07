//
//  SkyCalendarView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct SkyCalendarView: View {
    @Environment(\.di) private var di
    @State private var viewModel: SkyCalendarViewModel?
    @State private var selectedEntry: DiaryEntry?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: BHMetrics.spacingS), count: 7)

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
                let vm = SkyCalendarViewModel(repository: di.diaryRepository)
                viewModel = vm
                await vm.load()
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                SkyDetailView(entry: entry)
            }
        }
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

                    Text(viewModel.monthTitle)
                        .font(.bhHeadline)
                        .foregroundStyle(Color.bhTextPrimary)

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
                            .fill(Color.bhMistBlue.opacity(0.2))
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
        let normalized = Calendar.current.startOfDay(for: day)
        let sky = viewModel.skyByDay[normalized]

        return RoundedRectangle(cornerRadius: BHMetrics.cornerS, style: .continuous)
            .fill(sky?.weatherType.tileColor ?? Color.bhCloudGray.opacity(0.25))
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.bhTextSecondary.opacity(0.7))
                    .padding(3)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let entry = viewModel.entry(for: normalized) {
                    selectedEntry = entry
                }
            }
    }
}
