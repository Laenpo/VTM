//
//  TranslationEngine.swift
//  VTM
//
//  翻译引擎协议 — 抽象接口，支持 ML Kit / NLLB 等多引擎
//

import Foundation

/// 翻译引擎统一协议
/// 所有翻译引擎（ML Kit、NLLB-200 等）必须遵循此协议
protocol TranslationEngine: AnyObject {
    /// 引擎是否已就绪（模型已加载 / 已下载）
    var isReady: Bool { get }

    /// 引擎名称，用于 UI 显示
    var engineName: String { get }

    /// 异步翻译（回调版本）
    /// - Parameters:
    ///   - text: 源文本
    ///   - sourceLang: BCP-47 源语言代码（如 "zh", "en"）
    ///   - targetLang: BCP-47 目标语言代码
    ///   - completion: 结果回调，在主线程调用
    func translate(
        text: String,
        sourceLang: String,
        targetLang: String,
        completion: @escaping (Result<String, Error>) -> Void
    )

    /// 异步翻译（Swift Concurrency 版本）
    func translateAsync(
        text: String,
        sourceLang: String,
        targetLang: String
    ) async throws -> String
}
