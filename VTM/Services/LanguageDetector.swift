//
//  LanguageDetector.swift
//  VTM
//
//  语言自动检测 — 基于 Apple NLLanguageRecognizer
//  完全本地离线，无需网络
//  用于自动识别用户说话的源语言
//

import Foundation
import NaturalLanguage

// MARK: - LanguageDetector

enum LanguageDetector {

    /// 最低置信度阈值 — 低于此值不自动切换语言
    /// NLLanguageRecognizer 返回的 languageHints 概率通常 > 0.7 才可靠
    static let minimumConfidence: Double = 0.55

    /// 最短有效文本长度 — 太短的文本检测不可靠
    /// 设为 2：允许"你好""Hello"等短词触发语言检测
    static let minimumTextLength = 2

    /// 检测文本的主要语言
    /// - Parameters:
    ///   - text: 待检测文本
    ///   - currentLanguage: 当前已选源语言（用于对比，相同则不切换）
    /// - Returns: 检测到的语言短代码（如 "zh", "en"），或 nil（置信度不足或与当前相同）
    static func detectSourceLanguage(text: String, currentLanguage: String? = nil) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 文本太短 → 不检测
        guard trimmed.count >= minimumTextLength else {
            VTMLog.app("🔍 语言检测: 文本过短 (\(trimmed.count)字)，跳过")
            return nil
        }

        let recognizer = NLLanguageRecognizer()

        // 设定语言约束（只识别我们支持的 15 种语言）
        recognizer.languageConstraints = [
            .simplifiedChinese, .english, .japanese, .korean,
            .spanish, .french, .german, .portuguese,
            .russian, .arabic, .italian, .dutch,
            .polish, .turkish, .thai
        ]

        recognizer.processString(trimmed)

        guard let dominant = recognizer.dominantLanguage,
              let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant] else {
            VTMLog.app("🔍 语言检测: 无法识别")
            return nil
        }

        let detectedCode = mapToShortCode(dominant.rawValue)

        VTMLog.app("🔍 语言检测: \(dominant.rawValue) → \(detectedCode) (置信度: \(String(format: "%.2f", confidence)))")

        // 置信度不足 → 不切换
        guard confidence >= minimumConfidence else {
            VTMLog.app("🔍 语言检测: 置信度不足，保持当前语言")
            return nil
        }

        // 与当前语言相同 → 不切换
        let normCurrent = (currentLanguage ?? "").lowercased()
        if normCurrent == detectedCode || normCurrent.hasPrefix(detectedCode) {
            VTMLog.app("🔍 语言检测: 与当前语言 (\(normCurrent)) 一致，无需切换")
            return nil
        }

        return detectedCode
    }

    // MARK: - 语言代码映射

    /// 将 NLLanguageRecognizer 返回的 BCP-47 / 长代码映射为 VTM 内部短代码
    /// NLLanguageRecognizer 返回如 "zh-Hans", "en", "ja" 等
    /// VTM 内部使用 "zh", "en", "ja" 等短代码
    private static func mapToShortCode(_ rawCode: String) -> String {
        switch rawCode {
        // 中文变体统一为 "zh"
        case let code where code.hasPrefix("zh"): return "zh"

        // 英文变体统一为 "en"
        case let code where code.hasPrefix("en"): return "en"

        // 葡萄牙语变体
        case let code where code.hasPrefix("pt"): return "pt"

        // 西班牙语变体
        case let code where code.hasPrefix("es"): return "es"

        // 法语变体
        case let code where code.hasPrefix("fr"): return "fr"

        // 德语变体
        case let code where code.hasPrefix("de"): return "de"

        // 阿拉伯语变体
        case let code where code.hasPrefix("ar"): return "ar"

        // 荷兰语变体
        case let code where code.hasPrefix("nl"): return "nl"

        // 其他语言：取前 2 个字符（ja, ko, ru, it, pl, tr, th 等）
        default:
            if rawCode.count >= 2 {
                return String(rawCode.prefix(2)).lowercased()
            }
            return rawCode.lowercased()
        }
    }
}
