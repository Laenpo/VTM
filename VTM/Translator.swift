//
//  Translator.swift
//  VTM
//
//  VTM 翻译协调器 — 路由器自动选择 ML Kit (主力) / NLLB-200 (后备)
//
//  架构:
//    TranslationRouter
//      ├─ ⭐ MLKitTranslator (zh↔en 等主流语言，~30MB/语言对)
//      └─ 🔄 NLLBTranslator (罕见语言后备，~940MB，懒加载)
//
//  内存策略:
//     - 启动只加载 Whisper (~466MB)
//     - ML Kit 模型按需下载 (~30MB，首次翻译前预下载)
//     - NLLB 不预加载，仅在 ML Kit 不支持的语言对时按需加载
//

import Foundation
import Combine
import SwiftUI

final class Translator: ObservableObject {
    // MARK: - Published State

    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var isNLLBLoading: Bool = false

    /// 源语言（短代码 "zh"/"en" 等，@Published 直接驱动 UI 刷新）
    @Published var sourceLanguage: String = "zh"
    /// 目标语言（短代码 "zh"/"en" 等，@Published 直接驱动 UI 刷新）
    @Published var targetLanguage: String = "en"

    // MARK: - Init

    init() {
        // 从 UserDefaults 恢复上次设置
        if let saved = UserDefaults.standard.string(forKey: "sourceLanguage") {
            sourceLanguage = Self.normalizeBCP47(saved)
        }
        if let saved = UserDefaults.standard.string(forKey: "targetLanguage") {
            targetLanguage = Self.normalizeBCP47(saved)
        }

        // 监听 SettingsView / 跨进程语言切换（@AppStorage → UserDefaults）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // UserDefaults.didChangeNotification 的 userInfo 通常是 nil
        // 所以直接同步 @Published 属性，不做 key 过滤
        let newSource = Self.normalizeBCP47(
            UserDefaults.standard.string(forKey: "sourceLanguage") ?? "zh-CN"
        )
        let newTarget = Self.normalizeBCP47(
            UserDefaults.standard.string(forKey: "targetLanguage") ?? "en-US"
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.sourceLanguage != newSource || self.targetLanguage != newTarget {
                self.sourceLanguage = newSource
                self.targetLanguage = newTarget
            }
        }
    }

    // MARK: - Language Display

    /// 源语言显示名（供 UI 用）
    var sourceLanguageDisplay: LocalizedStringKey {
        LocalizedStringKey(Self.displayName(for: sourceLanguage))
    }

    /// 目标语言显示名（供 UI 用）
    var targetLanguageDisplay: LocalizedStringKey {
        LocalizedStringKey(Self.displayName(for: targetLanguage))
    }

    private static func normalizeBCP47(_ code: String) -> String {
        code.split(separator: "-").first.map(String.init) ?? code
    }

    static func displayName(for code: String) -> String {
        switch code {
        case "zh": return "中文"
        case "en": return "English"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "es": return "Español"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "pt": return "Português"
        case "ru": return "Русский"
        case "ar": return "العربية"
        case "it": return "Italiano"
        case "nl": return "Nederlands"
        case "pl": return "Polski"
        case "tr": return "Türkçe"
        case "th": return "ไทย"
        default: return code
        }
    }

    // MARK: - Engine

    /// 翻译路由器：根据语言对自动选择引擎
    private let router = TranslationRouter()

    /// NLLB 当前加载的模型名
    private var currentModelName: String?

    // MARK: - Public API: Translation

    /// 翻译文本 (回调版本) — 使用当前设置的语言对
    func translate(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success(""))
            return
        }

        Task { @MainActor in self.isTranslating = true }

        let engine = router.selectEngine(for: sourceLanguage, targetLang: targetLanguage)

        // 引擎未就绪 → 尝试 NLLB 懒加载
        guard engine.isReady else {
            if engine is NLLBTranslator, isNLLBDownloaded {
                // NLLB 已下载但未加载 → 懒加载后重试
                VTMLog.translation("🔄 NLLB 未加载，触发懒加载...")
                Task {
                    await loadNLLBIfAvailable()
                    if router.nllbEngine.isReady {
                        VTMLog.translation("✅ NLLB 懒加载完成，继续翻译")
                        // 加载成功 → 用 NLLB 执行翻译
                        router.nllbEngine.translate(
                            text: trimmed,
                            sourceLang: sourceLanguage,
                            targetLang: targetLanguage
                        ) { [weak self] result in
                            DispatchQueue.main.async {
                                self?.isTranslating = false
                                switch result {
                                case .success(let translated):
                                    self?.translatedText = translated
                                    completion(.success(translated))
                                case .failure(let error):
                                    self?.translatedText = ""
                                    print("❌ Translator (NLLB): \(error.localizedDescription)")
                                    completion(.failure(error))
                                }
                            }
                        }
                    } else {
                        // 加载失败
                        await MainActor.run { self.isTranslating = false }
                        completion(.failure(TranslatorError.engineNotReady("NLLB")))
                    }
                }
                return
            }

            // ML Kit 或其他引擎未就绪 → 直接报错
            Task { @MainActor in
                self.isTranslating = false
                let engineType = engine is MLKitTranslator ? "ML Kit" : "NLLB"
                completion(.failure(TranslatorError.engineNotReady(engineType)))
            }
            return
        }

        print("🔀 Translator: 使用 \(engine.engineName) 翻译 \(sourceLanguage)→\(targetLanguage)")

        engine.translate(
            text: trimmed,
            sourceLang: sourceLanguage,
            targetLang: targetLanguage
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isTranslating = false
                switch result {
                case .success(let translated):
                    self?.translatedText = translated
                    completion(.success(translated))
                case .failure(let error):
                    self?.translatedText = ""
                    print("❌ Translator (\(engine.engineName)): \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    /// 翻译文本 — 指定源语言和目标语言（对话模式专用）
    /// 临时切换语言对 → 执行翻译 → 恢复原语言对
    func translate(text: String, source: String, target: String, completion: @escaping (Result<String, Error>) -> Void) {
        let oldSource = sourceLanguage
        let oldTarget = targetLanguage
        setLanguages(source: source, target: target)
        translate(text: text) { result in
            self.setLanguages(source: oldSource, target: oldTarget)
            completion(result)
        }
    }

    /// 异步翻译 (Swift Concurrency)
    /// ⚠️ NLLB 未加载时自动懒加载
    func translateAsync(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        await MainActor.run { self.isTranslating = true }
        defer { Task { @MainActor in self.isTranslating = false } }

        let engine = router.selectEngine(for: sourceLanguage, targetLang: targetLanguage)

        // 引擎未就绪 → 尝试 NLLB 懒加载
        if !engine.isReady {
            if engine is NLLBTranslator, isNLLBDownloaded {
                VTMLog.translation("🔄 NLLB 未加载，触发懒加载...")
                await loadNLLBIfAvailable()

                guard router.nllbEngine.isReady else {
                    throw TranslatorError.engineNotReady("NLLB")
                }

                VTMLog.translation("✅ NLLB 懒加载完成，继续翻译")
                let result = try await router.nllbEngine.translateAsync(
                    text: trimmed,
                    sourceLang: sourceLanguage,
                    targetLang: targetLanguage
                )
                await MainActor.run { self.translatedText = result }
                return result
            }

            let engineType = engine is MLKitTranslator ? "ML Kit" : "NLLB"
            throw TranslatorError.engineNotReady(engineType)
        }

        let result = try await engine.translateAsync(
            text: trimmed,
            sourceLang: sourceLanguage,
            targetLang: targetLanguage
        )
        await MainActor.run { self.translatedText = result }
        return result
    }

    /// 设置语言（同时更新 @Published 属性 + 写入 UserDefaults 持久化）
    func setLanguages(source: String, target: String) {
        sourceLanguage = source
        targetLanguage = target
        UserDefaults.standard.set(Self.toBCP47(source), forKey: "sourceLanguage")
        UserDefaults.standard.set(Self.toBCP47(target), forKey: "targetLanguage")
    }

    private static func toBCP47(_ code: String) -> String {
        switch code {
        case "zh": return "zh-CN"
        case "en": return "en-US"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "pt": return "pt-PT"
        case "ru": return "ru-RU"
        case "ar": return "ar-SA"
        case "it": return "it-IT"
        case "nl": return "nl-NL"
        case "pl": return "pl-PL"
        case "tr": return "tr-TR"
        case "th": return "th-TH"
        default: return code
        }
    }

    // MARK: - Engine Status (供 UI 使用)

    /// ML Kit 翻译引擎是否就绪（当前语言对）
    var isMLKitReady: Bool {
        TranslationRouter.isMLKitSupported(
            sourceLang: sourceLanguage,
            targetLang: targetLanguage
        ) && router.isPrimaryReady
    }

    /// NLLB 后备引擎是否就绪
    var isNLLBReady: Bool {
        router.nllbEngine.isReady
    }

    /// NLLB 模型文件是否已下载到设备（不管是否加载到内存）
    var isNLLBDownloaded: Bool {
        NLModel.distilled600M.isFullyDownloaded
    }

    /// 当前语言对是否由 ML Kit 处理
    var isUsingMLKit: Bool {
        TranslationRouter.isMLKitSupported(
            sourceLang: sourceLanguage,
            targetLang: targetLanguage
        )
    }

    /// 当前活跃引擎名称
    var activeEngineName: LocalizedStringKey {
        if TranslationRouter.isMLKitSupported(
            sourceLang: sourceLanguage,
            targetLang: targetLanguage
        ) {
            return LocalizedStringKey(router.mlKitEngine.isReady ? "Google ML Kit" : "ML Kit (待下载)")
        } else if router.nllbEngine.isReady {
            return "NLLB-200"
        } else {
            return "未加载"
        }
    }

    /// 后备引擎名称
    var fallbackEngineName: LocalizedStringKey {
        LocalizedStringKey(router.nllbEngine.isReady ? "NLLB-200" : "NLLB · 未加载")
    }

    /// 当前加载的 NLLB 模型名
    var loadedModelName: String? {
        currentModelName
    }

    /// ML Kit 是否正在下载模型
    var isMLKitDownloading: Bool {
        router.mlKitEngine.isDownloadingModel
    }

    // MARK: - Model Management

    /// 预下载 ML Kit zh↔en 模型（异步，不阻塞 UI）
    func prewarmMLKit() {
        router.mlKitEngine.prewarm()
    }

    /// 尝试加载已下载的 NLLB 模型（后备引擎，按需懒加载）
    /// ⚠️ 加载前会通知 Whisper 主动卸载以释放 ~466MB 内存
    /// ⚠️ 异步后台执行（~940MB 模型加载不阻塞 UI）
    func loadNLLBIfAvailable() async {
        await MainActor.run { isNLLBLoading = true }
        defer { Task { @MainActor in self.isNLLBLoading = false } }

        // 🔑 关键：先让 Whisper 释放内存，避免 Whisper + NLLB 同时驻留导致 OOM
        VTMLog.memory("📢 通知 Whisper 卸载以释放内存...")
        NotificationCenter.default.post(name: NSNotification.Name("NLLBWillLoad"), object: nil)

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                for model in [NLModel.distilled600M] {
                    guard model.isFullyDownloaded,
                          let encoderPath = model.encoderPath,
                          let decoderPath = model.decoderPath,
                          let tokenizerPath = model.tokenizerPath else {
                        continue
                    }

                    do {
                        try self.router.nllbEngine.loadModel(
                            named: model.name,
                            encoderPath: encoderPath,
                            decoderPath: decoderPath,
                            tokenizerPath: tokenizerPath
                        )
                        DispatchQueue.main.async { self.currentModelName = model.name }
                        VTMLog.model("✅ NLLB 后备模型 \(model.name) 加载成功")
                        continuation.resume()
                        return
                    } catch {
                        VTMLog.error("加载 NLLB \(model.name) 失败 — \(error.localizedDescription)", category: "Model")
                        continue
                    }
                }

                VTMLog.model("ℹ️ 未找到已下载的 NLLB 后备模型")
                continuation.resume()
            }
        }
    }
}

// MARK: - Errors

enum TranslatorError: LocalizedError {
    case engineNotReady(String)

    var errorDescription: String? {
        switch self {
        case .engineNotReady(let name):
            return "翻译引擎 \"\(name)\" 未就绪，请检查模型是否已下载"
        }
    }
}
