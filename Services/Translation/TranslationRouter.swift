//
//  TranslationRouter.swift
//  VTM
//
//  翻译路由器 — 根据语言对自动选择最佳引擎
//  主力: Google ML Kit (zh↔en 等主流语言)
//  后备: NLLB-200 (罕见语言 / ML Kit 不支持的语言对)
//

import Foundation

/// 翻译路由器
/// 根据源语言和目标语言自动选择最合适的翻译引擎
final class TranslationRouter {
    // MARK: - Engines

    /// 主力引擎: Google ML Kit
    let mlKitEngine = MLKitTranslator()

    /// 后备引擎: NLLB-200
    let nllbEngine = NLLBTranslator()

    // MARK: - Language Support

    /// ML Kit 支持的语言对列表（BCP-47 格式）
    /// 数据来源: https://developers.google.com/ml-kit/language/translation/translation-language-support
    private static let mlKitSupportedLanguages: Set<String> = [
        "af", "ar", "be", "bg", "bn", "ca", "cs", "cy", "da", "de",
        "el", "en", "eo", "es", "et", "fa", "fi", "fr", "ga", "gl",
        "gu", "he", "hi", "hr", "ht", "hu", "id", "is", "it", "ja",
        "ka", "kn", "ko", "lt", "lv", "mk", "mr", "ms", "mt", "nl",
        "no", "pl", "pt", "ro", "ru", "sk", "sl", "sq", "sv", "sw",
        "ta", "te", "th", "tl", "tr", "uk", "ur", "vi", "zh"
    ]

    // MARK: - Public API

    /// 判断 ML Kit 是否支持给定语言对
    static func isMLKitSupported(sourceLang: String, targetLang: String) -> Bool {
        let source = normalizeLanguageCode(sourceLang)
        let target = normalizeLanguageCode(targetLang)
        return mlKitSupportedLanguages.contains(source)
            && mlKitSupportedLanguages.contains(target)
    }

    /// 根据语言对选择引擎
    func selectEngine(for sourceLang: String, targetLang: String) -> TranslationEngine {
        if Self.isMLKitSupported(sourceLang: sourceLang, targetLang: targetLang) {
            return mlKitEngine
        } else {
            return nllbEngine
        }
    }

    /// 主力引擎是否就绪
    var isPrimaryReady: Bool {
        mlKitEngine.isReady
    }

    /// 后备引擎是否就绪
    var isFallbackReady: Bool {
        nllbEngine.isReady
    }

    /// 当前是否有任一引擎可用（用于快速判断）
    var hasAnyReadyEngine: Bool {
        mlKitEngine.isReady || nllbEngine.isReady
    }

    // MARK: - Helpers

    /// 标准化 BCP-47 语言代码 → 提取主语言标签
    /// 例如 "zh-Hans" → "zh", "en-US" → "en"
    private static func normalizeLanguageCode(_ code: String) -> String {
        // BCP-47 格式: language[-script][-region]
        // 我们只需要主语言标签来判断 ML Kit 支持
        let components = code.split(separator: "-")
        return components.first.map(String.init) ?? code
    }
}
