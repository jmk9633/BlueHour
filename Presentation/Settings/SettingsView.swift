//
//  SettingsView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.di) private var di
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        ZStack {
            Color.bhBackground.ignoresSafeArea()

            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(repository: di.diaryRepository)
            }
        }
    }

    private func content(_ viewModel: SettingsViewModel) -> some View {
        List {
            Section("잠금") {
                Toggle("Face ID로 잠그기", isOn: bindFaceID(viewModel))
            }

            Section("음성") {
                Toggle("원본 음성 기기에 저장", isOn: bindSaveAudio(viewModel))
            }

            Section("데이터") {
                Button("데이터 내보내기") {
                    // 내보내기는 6단계 이후 확장 지점
                }
                .foregroundStyle(Color.bhTextPrimary)

                Button("모든 기록 삭제", role: .destructive) {
                    viewModel.requestDeleteAll()
                }
            }

            Section {
                HStack {
                    Text("앱 정보")
                    Spacer()
                    Text("블루아워 v0")
                        .foregroundStyle(Color.bhTextSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bhBackground)
        .font(.bhBody)
        .alert("모든 기록을 삭제할까요?", isPresented: bindDeleteAlert(viewModel)) {
            Button("취소", role: .cancel) { viewModel.cancelDelete() }
            Button("삭제", role: .destructive) {
                Task { await viewModel.confirmDeleteAll() }
            }
        } message: {
            Text("삭제한 하늘은 되돌릴 수 없어요.")
        }
    }

    // MARK: - 바인딩 헬퍼 (Observable 속성을 Toggle/alert에 연결)

    private func bindFaceID(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { vm.useFaceIDLock }, set: { vm.useFaceIDLock = $0 })
    }

    private func bindSaveAudio(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { vm.saveOriginalAudio }, set: { vm.saveOriginalAudio = $0 })
    }

    private func bindDeleteAlert(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { vm.showDeleteConfirmation }, set: { if !$0 { vm.cancelDelete() } })
    }
}
