//
//  AudioPlaybackController.swift
//  BlueHour
//
//  '그날의 목소리' 재생을 담당한다. (S-OCQTHP)
//  - 재생/일시정지, 경과 시간, 전체 길이, 진행률을 제공한다.
//  - stop()은 재생을 멈추고 오디오 세션을 비활성화해, 이어지는 '다시 말하기' 녹음의
//    세션 설정(playAndRecord)과 충돌하지 않게 한다.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlaybackController: NSObject {

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// 0...1 진행률 (진행 막대에 사용)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    // MARK: - 로드 / 재생 제어

    func load(url: URL) {
        // 이미 재생 중이던 것이 있으면 정리
        stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        duration = player?.duration ?? 0
        currentTime = 0
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        player.play()
        isPlaying = true
        startTicker()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTicker()
        // 일시정지에서도 세션을 내려 녹음 세션과 겹치지 않게 한다.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 재생을 완전히 멈추고 처음으로 되돌린다. 화면을 벗어나거나 수정/다시 말하기/삭제로 넘어갈 때 호출한다.
    func stop() {
        ticker?.cancel()
        ticker = nil
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 경과 시간 갱신

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { break }
                guard let player = self.player, player.isPlaying else { continue }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}

extension AudioPlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}
