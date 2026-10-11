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
                viewModel = SettingsViewModel(
                    repository: di.diaryRepository,
                    audioService: di.audioService
                )
            }
        }
    }

    private func content(_ viewModel: SettingsViewModel) -> some View {
        List {
            Section("잠금") {
                Toggle("Face ID로 잠그기", isOn: bindFaceID(viewModel))
            }

            Section {
                Picker("음성 저장 방식", selection: bindSaveAudio(viewModel)) {
                    Text("목소리 남기기").tag(true)
                    Text("글과 하늘만 남기기").tag(false)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("음성")
            } footer: {
                Text("새로 만드는 기록부터 적용돼요. 지난 기록은 그대로예요.")
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
        .alert("잠금을 사용할 수 없어요", isPresented: bindLockUnavailableAlert(viewModel)) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("기기에 암호를 설정하면 잠금을 사용할 수 있어요.")
        }
    }

    // MARK: - 바인딩 헬퍼 (Observable 속성을 Toggle/alert에 연결)

    private func bindFaceID(_ vm: SettingsViewModel) -> Binding<Bool> {
        // 켜기는 인증을 거쳐야 하므로, 토글 조작을 ViewModel에 비동기로 위임한다.
        // (인증 실패·불가 시 useFaceIDLock이 그대로라 토글이 되돌아온다.)
        Binding(get: { vm.useFaceIDLock }, set: { newValue in
            Task { await vm.requestFaceIDLock(newValue) }
        })
    }

    private func bindSaveAudio(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { vm.saveOriginalAudio }, set: { vm.saveOriginalAudio = $0 })
    }

    private func bindDeleteAlert(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { vm.showDeleteConfirmation }, set: { if !$0 { vm.cancelDelete() } })
    }

    private func bindLockUnavailableAlert(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { vm.showLockUnavailableAlert }, set: { vm.showLockUnavailableAlert = $0 })
    }
}
