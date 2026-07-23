//
//  VTMLogger.swift
//  VTM
//
//  统一日志工具 — 基于 os.Logger (iOS 14+)
//  - 真机通过 macOS Console.app 查看（搜索 process:VTM）
//  - 模拟器通过 Xcode Console 查看
//  - 同步输出到 print() 兼容旧调试习惯
//

import Foundation
import os

// MARK: - Logger 分类

extension Logger {
    /// VTM 子系统标识
    private static var subsystem: String {
        Bundle.main.bundleIdentifier ?? "com.alexzhang.VTM"
    }

    /// 模型加载相关（Whisper / NLLB / ML Kit）
    static let model = Logger(subsystem: subsystem, category: "Model")

    /// 翻译相关（翻译请求 / 引擎切换 / 结果）
    static let translation = Logger(subsystem: subsystem, category: "Translation")

    /// 语音识别相关（录音 / 转写 / 音频）
    static let speech = Logger(subsystem: subsystem, category: "Speech")

    /// TTS 语音合成
    static let tts = Logger(subsystem: subsystem, category: "TTS")

    /// 内存管理（内存警告 / OOM / 卸载）
    static let memory = Logger(subsystem: subsystem, category: "Memory")

    /// 下载管理（模型下载进度 / 错误）
    static let download = Logger(subsystem: subsystem, category: "Download")

    /// App 生命周期 / 通用事件
    static let app = Logger(subsystem: subsystem, category: "App")
}

// MARK: - 便捷输出（同步 print + os_log）

enum VTMLog {
    /// 模型加载
    static func model(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[Model] \(message)")
#endif
        Logger.model.log(level: level, "\(message, privacy: .public)")
    }

    /// 翻译流程
    static func translation(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[Translation] \(message)")
#endif
        Logger.translation.log(level: level, "\(message, privacy: .public)")
    }

    /// 语音识别
    static func speech(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[Speech] \(message)")
#endif
        Logger.speech.log(level: level, "\(message, privacy: .public)")
    }

    /// TTS
    static func tts(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[TTS] \(message)")
#endif
        Logger.tts.log(level: level, "\(message, privacy: .public)")
    }

    /// 内存管理
    static func memory(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[Memory] \(message)")
#endif
        Logger.memory.log(level: level, "\(message, privacy: .public)")
    }

    /// 下载
    static func download(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[Download] \(message)")
#endif
        Logger.download.log(level: level, "\(message, privacy: .public)")
    }

    /// App 生命周期
    static func app(_ message: String, level: OSLogType = .info) {
#if DEBUG
        print("[App] \(message)")
#endif
        Logger.app.log(level: level, "\(message, privacy: .public)")
    }

    /// 错误级别
    static func error(_ message: String, category: String = "App") {
#if DEBUG
        print("[\(category)] ❌ \(message)")
#endif
        switch category {
        case "Model": Logger.model.error("❌ \(message, privacy: .public)")
        case "Translation": Logger.translation.error("❌ \(message, privacy: .public)")
        case "Speech": Logger.speech.error("❌ \(message, privacy: .public)")
        case "TTS": Logger.tts.error("❌ \(message, privacy: .public)")
        case "Memory": Logger.memory.error("❌ \(message, privacy: .public)")
        case "Download": Logger.download.error("❌ \(message, privacy: .public)")
        default: Logger.app.error("❌ \(message, privacy: .public)")
        }
    }
}
