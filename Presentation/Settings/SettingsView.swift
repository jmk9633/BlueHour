//
//  SettingsView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.di) private var di
    @State private var viewModel: SettingsViewModel?
    @State private var showPurchase = false
    @State private var restoreMessage: String?

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
                    audioService: di.audioService,
                    freeSkyCounter: di.freeSkyCounter,
                    purchaseController: di.purchaseController,
                    reminderController: di.nightReminderController
                )
            }
        }
    }

    private func content(_ viewModel: SettingsViewModel) -> some View {
        List {
            Section("잠금") {
                Toggle("Face ID로 잠그기", isOn: bindFaceID(viewModel))
            }

            Section("알림") {
                Toggle("밤 리마인더", isOn: bindReminder(viewModel))
                if viewModel.reminderController.isEnabled {
                    DatePicker(
                        "알림 시간",
                        selection: bindReminderTime(viewModel),
                        displayedComponents: .hourAndMinute
                    )
                }
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

            Section("이용") {
                if viewModel.isUnlocked {
                    HStack {
                        Text("이용 상태")
                        Spacer()
                        Text("평생 이용 중")
                            .foregroundStyle(Color.bhTextSecondary)
                    }
                } else {
                    Button {
                        showPurchase = true
                    } label: {
                        HStack {
                            Text("무료로 담은 하늘")
                            Spacer()
                            Text("\(viewModel.freeCount) / \(viewModel.freeLimit)")
                                .foregroundStyle(Color.bhTextSecondary)
                        }
                    }
                    .foregroundStyle(Color.bhTextPrimary)
                }

                Button("구매 복원") {
                    Task { restoreMessage = await viewModel.restore() }
                }
                .foregroundStyle(Color.bhTextPrimary)
            }

            Section {
                HStack {
                    Text("앱 정보")
                    Spacer()
                    Text("블루아워 \(appVersion)")
                        .foregroundStyle(Color.bhTextSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bhBackground)
        .font(.bhBody)
        .sheet(isPresented: $showPurchase) {
            PurchaseView(
                controller: viewModel.purchaseController,
                analysisService: di.analysisService
            ) {
                showPurchase = false
            }
        }
        .alert("구매 복원", isPresented: bindRestoreAlert()) {
            Button("확인", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
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
        .alert("설정에서 알림을 허용해 주세요.", isPresented: bindReminderPermissionAlert(viewModel)) {
            Button("설정 열기") { openSystemSettings() }
            Button("취소", role: .cancel) { }
        }
    }

    /// iOS 설정 앱의 이 앱 화면을 연다.
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - 앱 버전 (F-SAZNQX)

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "0"
    }

    // MARK: - 바인딩 헬퍼 (Observable 속성을 Toggle/alert에 연결)

    private func bindRestoreAlert() -> Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }

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

    // MARK: - 밤 리마인더 바인딩 (F-LDUDEX)

    /// 토글. 켜기는 권한 확인·요청을 거치므로 ViewModel에 비동기로 위임한다.
    /// (권한 거부·불가 시 isEnabled가 false로 유지돼 토글이 되돌아온다.)
    private func bindReminder(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { vm.reminderController.isEnabled },
            set: { newValue in Task { await vm.reminderController.setEnabled(newValue) } }
        )
    }

    /// 알림 시간. 시·분만 쓰고, 바뀌면 재예약한다.
    private func bindReminderTime(_ vm: SettingsViewModel) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                return calendar.date(
                    bySettingHour: vm.reminderController.reminderHour,
                    minute: vm.reminderController.reminderMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let hour = comps.hour ?? 22
                let minute = comps.minute ?? 30
                Task { await vm.reminderController.setTime(hour: hour, minute: minute) }
            }
        )
    }

    private func bindReminderPermissionAlert(_ vm: SettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { vm.reminderController.showPermissionDeniedNotice },
            set: { vm.reminderController.showPermissionDeniedNotice = $0 }
        )
    }
}
