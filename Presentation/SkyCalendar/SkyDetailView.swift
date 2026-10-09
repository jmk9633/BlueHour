//
//  SkyDetailView.swift
//  BlueHour
//

import SwiftUI

struct SkyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.di) private var di

    private let initialEntry: DiaryEntry
    /// 삭제/수정/다시 말하기로 데이터가 바뀌었을 때 캘린더·오늘 탭을 새로고침하도록 알림
    private let onChanged: () -> Void

    @State private var viewModel: SkyDetailViewModel?
    @State private var playback = AudioPlaybackController()

    /// 재생 가능한 음성 파일 URL (파일이 없으면 nil → 목소리 영역 숨김)
    @State private var voiceURL: URL?

    @State private var showDeleteConfirmation = false
    @State private var showEraseConfirmation = false
    @State private var showRespeakConfirmation = false
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case edit, respeak
        var id: Int { hashValue }
    }

    init(entry: DiaryEntry, onChanged: @escaping () -> Void) {
        self.initialEntry = entry
        self.onChanged = onChanged
    }

    var body: some View {
        ScrollView {
            if let viewModel {
                content(viewModel)
            }
        }
        .background(Color.bhBackground.ignoresSafeArea())
        .toolbar { toolbarMenu }
        .task {
            if viewModel == nil {
                viewModel = SkyDetailViewModel(
                    entry: initialEntry,
                    repository: di.diaryRepository,
                    audioService: di.audioService
                )
            }
            await resolveVoice()
        }
        // 시트를 닫으면(화면을 벗어나면) 재생을 멈춘다.
        .onDisappear { playback.stop() }
        .alert("이 날의 하늘을 지울까요?", isPresented: $showDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("지우기", role: .destructive) {
                Task {
                    await viewModel?.deleteEntry()
                    onChanged()
                    dismiss()
                }
            }
        } message: {
            Text("지운 기록은 되돌릴 수 없어요.")
        }
        .alert("이 날의 목소리를 지울까요?", isPresented: $showEraseConfirmation) {
            Button("취소", role: .cancel) {}
            Button("지우기", role: .destructive) {
                Task {
                    await viewModel?.eraseVoice()
                    await resolveVoice()
                    onChanged()
                }
            }
        } message: {
            Text("하늘과 글은 그대로 남아요. 지운 목소리는 되돌릴 수 없어요.")
        }
        .alert("오늘의 하늘을 다시 그릴까요?", isPresented: $showRespeakConfirmation) {
            Button("다시 말하기") { activeSheet = .respeak }
            Button("취소", role: .cancel) {}
        } message: {
            Text("새로 말하면 이전 기록은 사라져요.")
        }
        .sheet(item: $activeSheet) { sheet in
            recordFlowSheet(sheet)
        }
    }

    // MARK: - 본문

    @ViewBuilder
    private func content(_ viewModel: SkyDetailViewModel) -> some View {
        let entry = viewModel.entry
        VStack(alignment: .leading, spacing: BHMetrics.spacingL) {

            Text(dateText(for: entry))
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)

            if let analysis = entry.analysis {
                Text(analysis.title)
                    .font(.bhHeadline)
                    .foregroundStyle(Color.bhTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(analysis.summary)
                    .font(.bhBody)
                    .foregroundStyle(Color.bhTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !analysis.emotionKeywords.isEmpty {
                    section("감정 키워드") {
                        HStack(spacing: BHMetrics.spacingS) {
                            ForEach(analysis.emotionKeywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.bhCaption)
                                    .padding(.horizontal, BHMetrics.spacingM)
                                    .padding(.vertical, BHMetrics.spacingS)
                                    .background(Capsule().fill(Color.bhMistBlue.opacity(0.3)))
                                    .foregroundStyle(Color.bhTextPrimary)
                            }
                        }
                    }
                }

                if let theme = analysis.mainTheme {
                    section("오늘 마음에 남은 것") { bodyText(theme) }
                }

                // 회복의 신호 (없으면 숨김)
                if let recovery = analysis.recoverySignal {
                    section("회복의 신호") { bodyText(recovery) }
                }

                section("내일의 작은 문장") { bodyText(analysis.tomorrowSentence) }
            } else {
                // 아직 그려지지 않은 하늘 — 글과 목소리는 아래에 그대로 보여준다.
                Text("이 날의 하늘은 아직 비어 있어요.")
                    .font(.bhBody)
                    .foregroundStyle(Color.bhTextSecondary)
            }

            // 그날의 기록(원문) — 분석 유무와 무관하게 표시
            if let transcript = entry.transcript {
                DisclosureGroup {
                    Text(transcript.displayText)
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

            // 그날의 목소리 — 파일이 있을 때만
            if voiceURL != nil {
                voiceSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BHMetrics.screenPadding)
    }

    // MARK: - 그날의 목소리 (S-OCQTHP)

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
            Text("그날의 목소리")
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)

            HStack(spacing: BHMetrics.spacingM) {
                Button {
                    playback.togglePlay()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.bhAccent)
                }

                VStack(alignment: .leading, spacing: BHMetrics.spacingXS) {
                    // 진행 막대
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.bhCloudGray.opacity(0.4))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.bhAccent)
                                .frame(width: geo.size.width * playback.progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    // 경과 / 전체 길이
                    HStack {
                        Text(timeString(playback.currentTime))
                        Spacer()
                        Text(timeString(playback.duration))
                    }
                    .font(.bhLabel)
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

    // MARK: - 툴바 메뉴

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: BHMetrics.spacingL) {
                Menu {
                    Button("수정") {
                        playback.stop()
                        activeSheet = .edit
                    }
                    Button("다시 말하기") {
                        playback.stop()
                        showRespeakConfirmation = true
                    }
                    if viewModel?.hasVoice == true {
                        Button("목소리 지우기") {
                            playback.stop()
                            showEraseConfirmation = true
                        }
                    }
                    Button("삭제", role: .destructive) {
                        playback.stop()
                        showDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }

                Button {
                    playback.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
            .foregroundStyle(Color.bhTextSecondary)
        }
    }

    // MARK: - 수정 / 다시 말하기 시트

    @ViewBuilder
    private func recordFlowSheet(_ sheet: ActiveSheet) -> some View {
        if let entry = viewModel?.entry {
            switch sheet {
            case .edit:
                RecordFlowView(targetDate: entry.date, editingEntry: entry) {
                    activeSheet = nil
                    Task { await refreshAfterChange() }
                }
            case .respeak:
                RecordFlowView(targetDate: entry.date, replaceExisting: true) {
                    activeSheet = nil
                    Task { await refreshAfterChange() }
                }
            }
        }
    }

    // MARK: - 동작 보조

    private func refreshAfterChange() async {
        await viewModel?.reload()
        await resolveVoice()
        onChanged()
    }

    /// 현재 기록의 음성 파일을 확인해 재생 준비한다. 없으면 목소리 영역을 숨긴다.
    private func resolveVoice() async {
        playback.stop()
        voiceURL = nil
        guard let fileName = viewModel?.entry.recording?.fileName else { return }
        let url = await di.audioService.fileURL(for: fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            voiceURL = url
            playback.load(url: url)
        }
    }

    // MARK: - 보조 뷰 / 포맷

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BHMetrics.spacingS) {
            Text(title)
                .font(.bhCaption)
                .foregroundStyle(Color.bhTextSecondary)
            content()
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.bhBody)
            .foregroundStyle(Color.bhTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dateText(for entry: DiaryEntry) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: entry.date)
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
