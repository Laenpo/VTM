//
//  TTSManager.swift
//  VTM
//
//  TTS 语音合成管理器 - AVSpeechSynthesizer
//

import Foundation
import AVFoundation
import Combine

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 朗读文本
    /// - Parameters:
    ///   - text: 要朗读的文本
    ///   - language: BCP-47 语言代码 (默认 en-US)
    func speak(text: String, language: String = "en-US") {
        guard !text.isEmpty else {
            print("⚠️ TTS: 文本为空，跳过")
            return
        }

        // 停止当前播放
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // 配置音频会话为播放模式（等待录音清理完成）
        configurePlaybackSession()

        // 创建语音合成请求
        let utterance = AVSpeechUtterance(string: text)

        // 匹配语音
        if let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        } else if let defaultVoice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = defaultVoice
            print("🔊 TTS: \(language) 不可用, 回退到 en-US")
        } else {
            print("⚠️ TTS: 无可用的 TTS 语音")
            return
        }

        print("🔊 TTS: 使用语音 \(utterance.voice?.language ?? "unknown")")

        utterance.rate = 0.48          // 稍慢，更清晰
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1   // 给音频系统预热时间
        utterance.postUtteranceDelay = 0.05

        DispatchQueue.main.async {
            self.isSpeaking = true
        }

        print("🔊 TTS: 开始播放 \"\(text.prefix(40))\(text.count > 40 ? "..." : "")\"")
        synthesizer.speak(utterance)
    }

    /// 配置纯播放音频会话
    private func configurePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("⚠️ TTS 音频会话失败: \(error.localizedDescription)")
        }
    }

    /// 停止播放
    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 TTS: 播放开始")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 TTS: 播放完成")
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
