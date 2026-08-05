//
//  ReviewView.swift
//  BlueHour
//
//  Created by 정문기 on 6/5/26.
//

import SwiftUI

struct ReviewView: View {
    @Bindable var viewModel: RecordFlowViewModel

    // 텍스트 입력창의 포커스 상태 (키보드 내림 제어에 사용)
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BHMetrics.spacingL) {
                Text("오늘 말한 내용이에요")
                    .font(.bhHeadline)
                    .foregroundStyle(Color.bhTextPrimary)

                Text("어색한 부분이 있다면\n가볍게 다듬어도 좋아요.")
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)

                TextEditor(text: $viewModel.editableText)
                    .font(.bhBody)
                    .foregroundStyle(Color.bhTextPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .padding(BHMetrics.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: BHMetrics.cornerM, style: .continuous)
                            .fill(Color.bhMistBlue.opacity(0.3))
                    )
                    .frame(height: 240)
                    .overlay(alignment: .topLeading) {
                        // 비어 있을 때만 보이는 안내 글자
                        if viewModel.editableText.isEmpty {
                            Text("오늘 하루를 가볍게 적어보세요.")
                                .font(.bhBody)
                                .foregroundStyle(Color.bhTextSecondary.opacity(0.6))
                                .padding(BHMetrics.spacingM)
                                .padding(.top, 8)
                                .allowsHitTesting(false)  // 글자가 입력을 가로막지 않게
                        }
                    }
            }
            .padding(BHMetrics.screenPadding)
        }
        // 방법 1) 화면을 스크롤하면 키보드가 내려감.
        // 콘텐츠가 짧아도 항상 드래그되도록 bounce를 켜서 스크롤 제스처를 보장.
        .scrollBounceBehavior(.always)
        .scrollDismissesKeyboard(.immediately)
        // 방법 2) 입력창 이외의 영역을 탭하면 키보드가 내려감
        .contentShape(Rectangle())
        .onTapGesture {
            isEditorFocused = false
        }
        // 하단: 입력 중에는 방법 3) 키보드 위 툴바(내림 버튼), 평소에는 CTA 버튼.
        // safeAreaInset은 키보드가 올라오면 그 위로 밀려 올라가 키보드 툴바처럼 동작한다.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEditorFocused {
                keyboardToolbar
            } else {
                Button("오늘의 하늘 보기") {
                    Task { await viewModel.confirmAndAnalyze() }
                }
                .buttonStyle(.bhPrimary)
                .padding(BHMetrics.screenPadding)
            }
        }
    }

    // 방법 3) 키보드 위에 꽉 차는 툴바. 우측에 키보드 내림 아이콘.
    private var keyboardToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button {
                    isEditorFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                        .foregroundStyle(Color.bhTextSecondary)
                }
            }
            .padding(.horizontal, BHMetrics.screenPadding)
            .padding(.vertical, BHMetrics.spacingS)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}
