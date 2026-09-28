//
//  SkyDetailView.swift
//  BlueHour
//

import SwiftUI

struct SkyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.di) private var di

    @State private var entry: DiaryEntry
    /// 삭제/수정으로 데이터가 바뀌었을 때 캘린더를 새로고침하도록 알림
    private let onChanged: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var isEditing = false

    init(entry: DiaryEntry, onChanged: @escaping () -> Void) {
        _entry = State(initialValue: entry)
        self.onChanged = onChanged
    }

    private var analysis: SkyAnalysis? { entry.analysis }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BHMetrics.spacingL) {

                Text(dateText)
                    .font(.bhCaption)
                    .foregroundStyle(Color.bhTextSecondary)

                if let analysis {
                    Text(analysis.title)
                        .font(.bhHeadline)
                        .foregroundStyle(Color.bhTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(analysis.summary)
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextPrimary)

                    if !analysis.emotionKeywords.isEmpty {
                        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                            Text("감정 키워드")
                                .font(.bhCaption)
                                .foregroundStyle(Color.bhTextSecondary)
                            HStack(spacing: BHMetrics.spacingS) {
                                ForEach(analysis.emotionKeywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.bhCaption)
                                        .padding(.horizontal, BHMetrics.spacingM)
                                        .padding(.vertical, BHMetrics.spacingS)
                                        .background(
                                            Capsule().fill(Color.bhMistBlue.opacity(0.3))
                                        )
                                        .foregroundStyle(Color.bhTextPrimary)
                                }
                            }
                        }
                    }

                    if let theme = analysis.mainTheme {
                        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                            Text("오늘 마음에 남은 것")
                                .font(.bhCaption)
                                .foregroundStyle(Color.bhTextSecondary)
                            Text(theme)
                                .font(.bhBody)
                                .foregroundStyle(Color.bhTextPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
                        Text("내일의 작은 문장")
                            .font(.bhCaption)
                            .foregroundStyle(Color.bhTextSecondary)
                        Text(analysis.tomorrowSentence)
                            .font(.bhBody)
                            .foregroundStyle(Color.bhTextPrimary)
                    }

                    if let transcript = entry.transcript {
                        DisclosureGroup {
                            Text(transcript.editedText ?? transcript.originalText)
                                .font(.bhBody)
                                .foregroundStyle(Color.bhTextSecondary)
                                .padding(.top, BHMetrics.spacingS)
                        } label: {
                            Text("그날의 기록")
                                .font(.bhCaption)
                                .foregroundStyle(Color.bhTextSecondary)
                        }
                        .tint(Color.bhTextSecondary)
                    }
                } else {
                    Text("이 날의 하늘은 아직 비어 있어요.")
                        .font(.bhBody)
                        .foregroundStyle(Color.bhTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BHMetrics.screenPadding)
        }
        .background(Color.bhBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // 더보기(···) — X 바로 왼쪽. spacing으로 터치 타깃을 충분히 벌린다.
                HStack(spacing: BHMetrics.spacingL) {
                    Menu {
                        Button("수정") { isEditing = true }
                        Button("삭제", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                .foregroundStyle(Color.bhTextSecondary)
            }
        }
        .alert("이 날의 하늘을 지울까요?", isPresented: $showDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("지우기", role: .destructive) {
                Task { await delete() }
            }
        } message: {
            Text("지운 기록은 되돌릴 수 없어요.")
        }
        .sheet(isPresented: $isEditing) {
            // 과거 날짜 기록 플로우를 그대로 재사용하되, 기존 텍스트를 채워 텍스트 수정 모드로 진입
            RecordFlowView(targetDate: entry.date, editingEntry: entry) {
                isEditing = false
                Task { await refreshAfterEdit() }
            }
        }
    }

    // MARK: - 동작

    private func delete() async {
        // 원본 음성 파일도 함께 삭제해 고아 파일을 남기지 않는다
        if let fileName = entry.recording?.fileName {
            try? await di.audioService.deleteRecording(fileName: fileName)
        }
        try? await di.diaryRepository.delete(id: entry.id)
        onChanged()
        dismiss()
    }

    private func refreshAfterEdit() async {
        // 갱신된 엔트리를 다시 읽어 상세 화면에 반영하고, 캘린더도 새로고침
        if let updated = try? await di.diaryRepository.fetchEntry(on: entry.date) {
            entry = updated
        }
        onChanged()
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: entry.date)
    }
}
