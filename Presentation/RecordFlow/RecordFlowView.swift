//
//  RecordFlowView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct RecordFlowView: View {
    @Environment(\.di) private var di
    @Environment(\.scenePhase) private var scenePhase

    /// 이 기록이 저장될 대상 날짜. 오늘 탭은 논리적 오늘, 캘린더 진입 시 그 날짜.
    var targetDate: Date = BlueHourCalendar.startOfLogicalToday()
    /// 기존 기록을 텍스트로 수정할 때 넘기는 엔트리. 있으면 녹음 없이 리뷰 화면으로 바로 진입.
    var editingEntry: DiaryEntry? = nil
    /// 다시 말하기(기록 교체) 모드. 저장 시점에 대상 날짜의 기존 기록·음성을 새 기록으로 교체한다.
    var replaceExisting: Bool = false
    /// 흐름이 끝났을 때(결과 확인 후) 호출. 캘린더에서 시트로 띄운 경우 시트 닫기/새로고침에 사용.
    var onFinish: (() -> Void)? = nil

    @State private var viewModel: RecordFlowViewModel?
    /// 오늘의 하늘을 눌렀을 때 여는 상세 시트의 대상 엔트리.
    @State private var detailEntry: DiaryEntry?

    var body: some View {
        ZStack {
            Color.bhBackground.ignoresSafeArea()

            if let viewModel {
                VStack(spacing: 0) {
                    // 유일한 차이: 오늘이 아니면 상단에 대상일 헤더
                    if !viewModel.isTargetToday {
                        dateHeader(viewModel.targetDateText)
                    }

                    content(for: viewModel)
                        .frame(maxHeight: .infinity)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.state)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            // 화면이 처음 뜰 때 ViewModel을 DI 컨테이너로부터 조립
            if viewModel == nil {
                let vm = RecordFlowViewModel(
                    targetDate: targetDate,
                    replaceExisting: replaceExisting,
                    audioService: di.audioService,
                    speechService: di.speechService,
                    analysisService: di.analysisService,
                    repository: di.diaryRepository
                )
                // 수정 진입이면 녹음을 건너뛰고 기존 텍스트를 채운 리뷰 화면으로 시작
                if let editingEntry {
                    vm.startTextEdit(entry: editingEntry)
                }
                viewModel = vm
                await vm.loadExistingEntry()
            }
        }
        // 포그라운드 복귀 시 기록 상태를 다시 확인 (앱을 켜둔 채 새벽 4시를 넘기는 경우 대비)
        // 백그라운드로 들어갈 때 녹음 중이면 자동 정지하고 보존한다.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await viewModel?.loadExistingEntry() }
            case .background:
                if viewModel?.state == .recording {
                    Task { await viewModel?.handleInterruption() }
                }
            default:
                break
            }
        }
        // 화면을 벗어나면 인터럽션 옵저버를 해제한다.
        .onDisappear {
            viewModel?.viewDidDisappear()
        }
        // 오늘의 하늘 → 하늘 상세 시트 (기록 변경은 이 상세 시트의 ··· 메뉴로만)
        .sheet(item: $detailEntry) { entry in
            NavigationStack {
                SkyDetailView(entry: entry) {
                    Task { await viewModel?.loadExistingEntry() }
                }
            }
        }
    }

    private func dateHeader(_ text: String) -> some View {
        Text(text)
            .font(.bhLabel)
            .foregroundStyle(Color.bhTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, BHMetrics.spacingL)
    }

    @ViewBuilder
    private func content(for viewModel: RecordFlowViewModel) -> some View {
        switch viewModel.state {
        case .idle:
            TodayView(viewModel: viewModel) {
                detailEntry = viewModel.existingEntry
            }
        case .recording:
            RecordingView(viewModel: viewModel)
        case .interrupted:
            InterruptedView(viewModel: viewModel)
        case .permissionDenied:
            PermissionDeniedView(viewModel: viewModel)
        case .transcribing, .analyzing:
            AnalysisView(state: viewModel.state)
        case .reviewing:
            ReviewView(viewModel: viewModel)
        case .result:
            if let analysis = viewModel.analysis {
                ResultView(analysis: analysis) {
                    // 시트(캘린더)로 진입했으면 닫기, 오늘 탭이면 처음으로 되돌림
                    if let onFinish {
                        onFinish()
                    } else {
                        Task { await viewModel.restart() }
                    }
                }
            }
        case .savedWithoutSky:
            UndrawnSkyResultView {
                // 결과 카드와 동일한 닫기 동작 (시트면 닫기, 오늘 탭이면 처음으로)
                if let onFinish {
                    onFinish()
                } else {
                    Task { await viewModel.restart() }
                }
            }
        case .failed(let message):
            FailureView(message: message) {
                Task { await viewModel.restart() }
            }
        }
    }
}
