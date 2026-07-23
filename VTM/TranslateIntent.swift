//
//  TranslateIntent.swift
//  VTM
//
//  Siri Shortcuts — "Hey Siri, translate [text] using VTM"
//  iOS 16+ App Intents framework, 无需 Intents Extension
//

import AppIntents
import SwiftUI

/// Siri 快捷指令：接收文本，打开 VTM 并填入翻译源文本
@available(iOS 16.0, *)
struct TranslateIntent: AppIntent {
    static let title: LocalizedStringResource = "语音翻译"
    static let description = IntentDescription(
        "将文本粘贴到 VTM 翻译输入框中，方便直接查看翻译结果或朗读。",
        categoryName: "翻译"
    )

    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "要翻译的文本",
        description: "需要翻译的文字内容",
        requestValueDialog: "你想翻译什么？"
    )
    var text: String

    func perform() async throws -> some IntentResult & OpensIntent {
        // 将文本存入共享 UserDefaults，App 启动后读取
        if let shared = UserDefaults(suiteName: "group.com.alexzhang.VTM") {
            shared.set(text, forKey: "SiriTranslateText")
            shared.synchronize()
        }
        // 备用：标准 UserDefaults（App Groups 未配置时也能用）
        UserDefaults.standard.set(text, forKey: "SiriTranslateText")

        return .result()
    }
}

// MARK: - App Shortcuts Provider（注册到 Siri / 快捷指令 App）

@available(iOS 16.0, *)
struct VTMShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "用\(.applicationName)翻译",
                "使用\(.applicationName)翻译文本",
                "\(.applicationName)翻译",
            ],
            shortTitle: "语音翻译",
            systemImageName: "translate"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
