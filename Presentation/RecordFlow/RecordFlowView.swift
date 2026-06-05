//
//  RecordFlowView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct RecordFlowView: View {
    @Environment(\.di) private var di
    @State private var viewModel: RecordFlowViewModel?

    var body: some View {
        ZStack {
            Color.bhBackground.ignoresSafeArea()

            if let viewModel {
                content(for: viewModel)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.state)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            // 화면이 처음 뜰 때 ViewModel을 DI 컨테이너로부터 조립
            if viewModel == nil {
                viewModel = RecordFlowViewModel(
                    audioService: di.audioService,
                    speechService: di.speechService,
                    analysisService: di.analysisService,
                    repository: di.diaryRepository
                )
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: RecordFlowViewModel) -> some View {
        switch viewModel.state {
        case .idle:
            TodayView(viewModel: viewModel)
        case .recording:
            RecordingView(viewModel: viewModel)
        case .transcribing, .analyzing:
            AnalysisView(state: viewModel.state)
        case .reviewing:
            ReviewView(viewModel: viewModel)
        case .result:
            if let analysis = viewModel.analysis {
                ResultView(analysis: analysis) {
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
