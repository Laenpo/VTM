//
//  MLKitTranslator.swift
//  VTM
//
//  Google ML Kit 翻译引擎 — 主力翻译方案
//  使用 ML Kit Translate SDK，离线翻译，优先用于 zh↔en 等主流语言
//

import Foundation
import Combine
import MLKitTranslate

/// Google ML Kit 翻译引擎
/// 利用 ML Kit 的离线模型（~30MB/语言对），质量远优于 NLLB distilled
final class MLKitTranslator: NSObject, TranslationEngine {

    // MARK: - Published State

    /// 当前活跃的 MLKit Translator 实例（按语言对缓存）
    private var activeTranslator: MLKitTranslatorNative?

    /// 当前缓存的源语言
    private var cachedSourceLang: String?

    /// 当前缓存的目标语言
    private var cachedTargetLang: String?

    /// 模型是否已下载（缓存状态下可能不准确，实际以 ML Kit 内部判断为准）
    @Published var isModelDownloaded: Bool = false

    /// 是否正在下载模型
    @Published var isDownloadingModel: Bool = false

    // MARK: - TranslationEngine

    var engineName: String { "Google ML Kit" }

    var isReady: Bool {
        // ML Kit 不需要显式"加载"，模型按需下载
        // 只要 SDK 可用，即可认为就绪
        #if canImport(MLKitTranslate)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Public API

    /// 翻译文本（回调版本）
    func translate(
        text: String,
        sourceLang: String,
        targetLang: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        #if canImport(MLKitTranslate)
        performMLKitTranslation(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            completion: completion
        )
        #else
        completion(.failure(MLKitError.sdkNotAvailable))
        #endif
    }

    /// 翻译文本（async/await 版本）
    func translateAsync(
        text: String,
        sourceLang: String,
        targetLang: String
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            translate(text: text, sourceLang: sourceLang, targetLang: targetLang) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Private: ML Kit 实际调用

    #if canImport(MLKitTranslate)
    private func performMLKitTranslation(
        text: String,
        sourceLang: String,
        targetLang: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success(""))
            return
        }

        // 获取或创建 Translator 实例
        guard let sourceLanguage = translateLanguage(from: sourceLang),
              let targetLanguage = translateLanguage(from: targetLang) else {
            completion(.failure(MLKitError.unsupportedLanguage(sourceLang, targetLang)))
            return
        }

        let options = TranslatorOptions(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        let translator: MLKitTranslate.Translator = MLKitTranslate.Translator.translator(options: options)

        let conditions = ModelDownloadConditions(
            allowsCellularAccess: true,
            allowsBackgroundDownloading: false
        )

        // 🔑 始终走 downloadModelIfNeeded（ML Kit 自带幂等：已下载会秒过）
        // 不做预检查，避免 ModelManager 状态与实际文件不一致导致误判
        DispatchQueue.main.async { self.isDownloadingModel = true }
        VTMLog.translation("📥 ML Kit: 确保 zh↔en 模型已下载...")

        translator.downloadModelIfNeeded(with: conditions) { [weak self] (error: Error?) in
            DispatchQueue.main.async { self?.isDownloadingModel = false }

            if let error = error {
                VTMLog.error("ML Kit 模型下载失败: \(error.localizedDescription)", category: "Translation")
                completion(.failure(MLKitError.modelDownloadFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.main.async { self?.isModelDownloaded = true }
            VTMLog.translation("✅ ML Kit 模型就绪，开始翻译...")

            // 🔤 zh→en 翻译前：专有名词预替换（解决 ML Kit 不认识音译词的问题）
            let textToTranslate: String
            if sourceLang.hasPrefix("zh"), targetLang.hasPrefix("en") {
                textToTranslate = NamedEntityReplacer.preReplaceForChineseToEnglish(trimmed)
            } else {
                textToTranslate = trimmed
            }

            // 模型已确保下载，执行翻译
            translator.translate(textToTranslate) { translatedText, error in
                if let error = error {
                    VTMLog.error("ML Kit 翻译失败: \(error.localizedDescription)", category: "Translation")
                    completion(.failure(MLKitError.translationFailed(error.localizedDescription)))
                } else if let translated = translatedText {
                    // 后处理：检测并移除 ML Kit 偶尔产生的尾部重复短语
                    let deduped = Self.removeTrailingDuplication(translated)
                    if deduped != translated {
                        VTMLog.translation("🔁 ML Kit 去重: \"\(translated)\" → \"\(deduped)\"")
                    }
                    completion(.success(deduped))
                } else {
                    completion(.failure(MLKitError.emptyResult))
                }
            }
        }
    }

    // MARK: - Language Mapping

    /// 将 BCP-47 代码映射到 ML Kit TranslateLanguage
    /// ML Kit TranslateLanguage 的 rawValue 就是 BCP-47 主语言代码
    private func translateLanguage(from bcp47: String) -> TranslateLanguage? {
        let normalized = Self.normalizeBCP47(bcp47)
        return TranslateLanguage.allLanguages().first { lang in
            lang.rawValue == normalized
        }
    }
    #endif

    /// 标准化 BCP-47 → 主语言代码
    private static func normalizeBCP47(_ code: String) -> String {
        let components = code.split(separator: "-")
        return components.first.map(String.init) ?? code
    }

    // MARK: - Prewarm（预下载主力语言对模型）

    /// 预下载 ML Kit zh↔en 模型（异步，不阻塞）
    /// 在 App 启动时调用，确保第一次翻译前模型已就绪
    /// ⚠️ ML Kit 需要 source 和 target 两个语言模型都下载
    #if canImport(MLKitTranslate)
    func prewarm() {
        guard let sourceLanguage = translateLanguage(from: "zh"),
              let targetLanguage = translateLanguage(from: "en") else {
            VTMLog.error("ML Kit 预下载: zh/en 语言映射失败", category: "Translation")
            return
        }

        VTMLog.translation("📥 ML Kit 开始预下载 zh↔en 模型 (~30MB)...")

        let options = TranslatorOptions(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        let translator = MLKitTranslate.Translator.translator(options: options)

        // 🔑 强引用持有 Translator，防止异步回调期间被释放
        // 局部变量在 prewarm() 返回后立即出作用域，ML Kit 内部不会 retain
        activeTranslator = translator

        let conditions = ModelDownloadConditions(
            allowsCellularAccess: true,
            allowsBackgroundDownloading: false
        )

        DispatchQueue.main.async { self.isDownloadingModel = true }

        translator.downloadModelIfNeeded(with: conditions) { [weak self] error in
            DispatchQueue.main.async {
                self?.isDownloadingModel = false
                // 释放强引用
                self?.activeTranslator = nil
                if let error = error {
                    VTMLog.error("ML Kit 预下载失败: \(error.localizedDescription)", category: "Translation")
                } else {
                    self?.isModelDownloaded = true
                    VTMLog.translation("✅ ML Kit zh↔en 模型预下载完成")
                }
            }
        }
    }
    #else
    func prewarm() { /* ML Kit SDK 不可用 */ }
    #endif

    // MARK: - 尾部重复检测

    /// 检测并移除 ML Kit 翻译结果末尾的重复短语
    ///
    /// ML Kit 在离线翻译长句时偶尔会在尾部重复最后几个词，
    /// 例如 "I want to eat rice, I want to eat rice" → "I want to eat rice"
    ///
    /// 策略：将文本按词分割，检查是否存在尾部半截重复（n~n/2 词的滑动窗口），
    /// 如果检测到则截断重复部分
    static func removeTrailingDuplication(_ text: String) -> String {
        // 按词和标点分割（英文以空格为界，中文按字符）
        let isCJK = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3040...0x309F).contains(scalar.value) ||
            (0xAC00...0xD7AF).contains(scalar.value)
        }

        let tokens: [String]
        if isCJK {
            tokens = text.map { String($0) }
        } else {
            tokens = text.components(separatedBy: .whitespaces)
        }

        guard tokens.count >= 3 else { return text }

        // 尝试不同长度的重复检测（从一半到 2 个 token）
        let maxChunk = tokens.count / 2
        for chunkLen in stride(from: maxChunk, through: 2, by: -1) {
            let suffix = Array(tokens.suffix(chunkLen))
            let candidate = Array(tokens.dropLast(chunkLen).suffix(chunkLen))

            // 如果尾部 chunk 和前面的 chunk 完全相同，截断
            if suffix == candidate, !suffix.isEmpty {
                let deduped: String
                if isCJK {
                    deduped = String(tokens.dropLast(chunkLen).map { String($0) }.joined())
                } else {
                    deduped = tokens.dropLast(chunkLen).joined(separator: " ")
                }
                return deduped.trimmingCharacters(in: .whitespaces)
            }
        }

        return text
    }

    // Typealias for the actual ML Kit Translator class to avoid ambiguity
    // 使用完全限定名避免与模块内 Translator 类冲突
    private typealias MLKitTranslatorNative = MLKitTranslate.Translator
}

// MARK: - ML Kit 错误类型

enum MLKitError: LocalizedError {
    case sdkNotAvailable
    case unsupportedLanguage(String, String)
    case modelDownloadFailed(String)
    case translationFailed(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .sdkNotAvailable:
            return "ML Kit SDK 不可用，请检查项目配置"
        case .unsupportedLanguage(let src, let tgt):
            return "ML Kit 不支持 \"\(src)\" → \"\(tgt)\" 的语言对"
        case .modelDownloadFailed(let detail):
            return "ML Kit 模型下载失败: \(detail)"
        case .translationFailed(let detail):
            return "ML Kit 翻译失败: \(detail)"
        case .emptyResult:
            return "ML Kit 翻译返回空结果"
        }
    }
}
