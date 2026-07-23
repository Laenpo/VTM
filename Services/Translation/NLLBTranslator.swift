//
//  NLLBTranslator.swift
//  VTM
//
//  NLLB-200 ONNX 推理引擎 — VTM 主翻译引擎
//  - Encoder-Decoder 架构（双 ORTSession）
//  - KV-Cache 自回归 Greedy Decoding
//  - SentencePiece BPE Tokenizer
//
//  依赖:
//  - onnxruntime.xcframework (Frameworks/)
//  - ONNX Runtime Objective-C 源码 (Services/ONNXRuntime/)
//  - NLLBTokenizer.swift
//

import Foundation
import UIKit

// MARK: - NLLBTranslator Error

enum NLLBTranslatorError: Error, LocalizedError {
    case modelNotLoaded
    case tokenizerNotLoaded
    case ortEnvCreationFailed(String)
    case ortSessionCreationFailed(String)
    case ortRunFailed(String)
    case modelFileNotFound(String)
    case tokenizerFileNotFound(String)
    case tensorCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "NLLB 模型未加载"
        case .tokenizerNotLoaded: return "分词器未加载"
        case .ortEnvCreationFailed(let msg): return "ORT 环境创建失败: \(msg)"
        case .ortSessionCreationFailed(let msg): return "ORT 会话创建失败: \(msg)"
        case .ortRunFailed(let msg): return "推理失败: \(msg)"
        case .modelFileNotFound(let path): return "模型文件未找到: \(path)"
        case .tokenizerFileNotFound(let path): return "分词器文件未找到: \(path)"
        case .tensorCreationFailed(let msg): return "张量创建失败: \(msg)"
        }
    }
}

// MARK: - NLLBTranslator

final class NLLBTranslator: ObservableObject, @unchecked Sendable, TranslationEngine {
    // MARK: - Properties

    private var ortEnv: ORTEnv?
    private var encoderSession: ORTSession?
    private var decoderSession: ORTSession?
    private let tokenizer = NLLBTokenizer()

    private let queue = DispatchQueue(label: "com.vtm.nllb.translator", qos: .userInitiated)

    /// 当前加载的模型名称
    private(set) var loadedModelName: String?

    @Published var isModelLoaded: Bool = false
    @Published var isTokenizerLoaded: Bool = false
    @Published var isTranslating: Bool = false

    private var isLoadingModels = false

    var isReady: Bool { isModelLoaded && isTokenizerLoaded }

    /// TranslationEngine 协议: 引擎名称
    nonisolated var engineName: String { "NLLB-200" }

    // MARK: - Init

    init() {
        // 监听内存警告：内存不足时自动卸载模型防止 OOM 崩溃
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        guard !isLoadingModels else {
            VTMLog.memory("🟡 NLLB 收到内存警告但正在加载模型，跳过卸载")
            return
        }
        VTMLog.memory("🟡 NLLB 收到内存警告，卸载模型释放内存")
        unload()
    }

    // MARK: - Decoder I/O Names (12 层 × 2 注意力 × 2 KV = 48)

    private static let numLayers = 12
    private static let attentionTypes = ["decoder", "encoder"]
    private static let kvTypes = ["key", "value"]

    /// past_key_values.{layer}.{attn_type}.{kv}
    static func pastKeyValueNames(prefix: String) -> [String] {
        var names: [String] = []
        for layer in 0..<numLayers {
            for attn in attentionTypes {
                for kv in kvTypes {
                    names.append("\(prefix).\(layer).\(attn).\(kv)")
                }
            }
        }
        return names
    }

    // MARK: - Model Loading

    /// 加载 ONNX 模型（Encoder + Decoder）和分词器
    func loadModel(
        named modelName: String,
        encoderPath: URL,
        decoderPath: URL,
        tokenizerPath: URL
    ) throws {
        var loadSucceeded = false
        isLoadingModels = true
        defer {
            // 失败路径：模型加载中途抛异常 → 复位 isLoadingModels
            // 成功路径：由 DispatchQueue.main.async 内部复位（不在这里做）
            if !loadSucceeded {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoadingModels = false
                }
            }
        }
        VTMLog.model("🚀 加载 NLLB 模型: \(modelName)")

        // 1. 加载 ONNX Runtime 环境 (只需初始化一次)
        if ortEnv == nil {
            do {
                ortEnv = try ORTEnv(loggingLevel: .warning)
                VTMLog.model("  ✓ ORTEnv 初始化成功")
            } catch {
                throw NLLBTranslatorError.ortEnvCreationFailed(error.localizedDescription)
            }
        }

        // 2. 加载分词器
        guard FileManager.default.fileExists(atPath: tokenizerPath.path) else {
            throw NLLBTranslatorError.tokenizerFileNotFound(tokenizerPath.path)
        }

        do {
            try tokenizer.load(from: tokenizerPath)
            VTMLog.model("  ✓ 分词器加载成功 — 词表大小: \(tokenizer.isLoaded)")
            DispatchQueue.main.async { self.isTokenizerLoaded = true }
        } catch {
            throw NLLBTranslatorError.tokenizerFileNotFound(error.localizedDescription)
        }

        // 3. 加载 Encoder ONNX 模型
        guard FileManager.default.fileExists(atPath: encoderPath.path) else {
            throw NLLBTranslatorError.modelFileNotFound(encoderPath.path)
        }

        do {
            let sessionOptions = try createSessionOptions(optimizationLevel: .all)
            encoderSession = try ORTSession(
                env: ortEnv!,
                modelPath: encoderPath.path,
                sessionOptions: sessionOptions
            )
            VTMLog.model("  ✓ Encoder ORTSession 创建成功")
            if let inputs = try? encoderSession?.inputNames() {
                print("    Encoder 输入: \(inputs)")
            }
            if let outputs = try? encoderSession?.outputNames() {
                print("    Encoder 输出: \(outputs)")
            }
        } catch {
            throw NLLBTranslatorError.ortSessionCreationFailed("Encoder: \(error.localizedDescription)")
        }

        // 4. 加载 Decoder ONNX 模型
        guard FileManager.default.fileExists(atPath: decoderPath.path) else {
            throw NLLBTranslatorError.modelFileNotFound(decoderPath.path)
        }

        do {
            let sessionOptions = try createSessionOptions(optimizationLevel: .basic)
            decoderSession = try ORTSession(
                env: ortEnv!,
                modelPath: decoderPath.path,
                sessionOptions: sessionOptions
            )
            VTMLog.model("  ✓ Decoder ORTSession 创建成功")
        } catch {
            throw NLLBTranslatorError.ortSessionCreationFailed("Decoder: \(error.localizedDescription)")
        }

        loadedModelName = modelName
        loadSucceeded = true  // 标记成功：此后的 defer 不再复位
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 双重检查：确保 session 未被内存警告清除
            if self.encoderSession != nil && self.decoderSession != nil {
                self.isModelLoaded = true
                VTMLog.model("✅ NLLB 模型加载完成: \(modelName)")
            } else {
                VTMLog.model("⚠️ NLLB session 在加载后被清除，需要重新加载", level: .error)
            }
            // 关键：isLoadingModels 在 isModelLoaded 设置后才关闭
            // 防止内存警告在 DispatchQueue.main.async 执行前卸载模型
            self.isLoadingModels = false
        }
    }

    // MARK: - Translation API

    /// 翻译文本 (回调版本)
    func translate(
        text: String,
        sourceLang: String,
        targetLang: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(.success(""))
            return
        }

        guard isReady else {
            completion(.failure(NLLBTranslatorError.modelNotLoaded))
            return
        }

        DispatchQueue.main.async { self.isTranslating = true }

        let srcLang = NLLBLanguage.fromBCP47(sourceLang)
        let tgtLang = NLLBLanguage.fromBCP47(targetLang)

        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(NLLBTranslatorError.modelNotLoaded))
                }
                return
            }

            do {
                let result = try self.performTranslation(
                    text: text,
                    sourceLang: srcLang,
                    targetLang: tgtLang
                )
                DispatchQueue.main.async {
                    self.isTranslating = false
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTranslating = false
                    completion(.failure(error))
                }
            }
        }
    }

    /// 翻译文本 (async/await 版本)
    func translateAsync(
        text: String,
        sourceLang: String,
        targetLang: String
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        guard isReady else { throw NLLBTranslatorError.modelNotLoaded }

        await MainActor.run { self.isTranslating = true }
        defer { Task { @MainActor in self.isTranslating = false } }

        let srcLang = NLLBLanguage.fromBCP47(sourceLang)
        let tgtLang = NLLBLanguage.fromBCP47(targetLang)

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NLLBTranslatorError.modelNotLoaded)
                    return
                }
                do {
                    let result = try self.performTranslation(
                        text: text,
                        sourceLang: srcLang,
                        targetLang: tgtLang
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private: Encoder → Decoder 自回归生成

    private func performTranslation(
        text: String,
        sourceLang: NLLBLanguage,
        targetLang: NLLBLanguage,
        maxLength: Int = 128,
        minNewTokens: Int = 20
    ) throws -> String {
        guard let encoderSession = encoderSession,
              let decoderSession = decoderSession else {
            throw NLLBTranslatorError.modelNotLoaded
        }

        // ── 1. Tokenize ──────────────────────────────────────
        let inputIds = try tokenizer.encode(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            maxLength: maxLength
        )
        let srcLen = inputIds.count
        let paddedIds = tokenizer.pad(inputIds, toLength: maxLength)
        let attentionMask = NLLBTokenizer.createAttentionMask(
            tokenIds: inputIds,
            padTokenId: 1,
            totalLength: maxLength
        )

        print("📝 Tokenized: \(srcLen) tokens → \(text.prefix(30))...")

        // ── 2. Encoder 前向 ──────────────────────────────────
        let encInputTensor = try createInt64Tensor(paddedIds, shape: [1, maxLength])
        let encMaskTensor = try createInt64Tensor(attentionMask.map { Int($0) }, shape: [1, maxLength])

        let encoderOutputs: [String: ORTValue]
        do {
            encoderOutputs = try encoderSession.run(
                withInputs: ["input_ids": encInputTensor, "attention_mask": encMaskTensor],
                outputNames: ["last_hidden_state"],
                runOptions: nil
            )
        } catch let e as NLLBTranslatorError { throw e }
        catch { throw NLLBTranslatorError.ortRunFailed("Encoder: \(error.localizedDescription)") }

        guard let encHiddenStates = encoderOutputs["last_hidden_state"] else {
            throw NLLBTranslatorError.ortRunFailed("Encoder 未输出 last_hidden_state")
        }

        print("  ✓ Encoder 完成, hidden_states shape: \(shapeString(encHiddenStates))")

        // Encoder 输出诊断：采样前几个值验证非零
        let encData = try encHiddenStates.tensorData() as Data
        let encFloats = encData.withUnsafeBytes { ptr in Array(ptr.bindMemory(to: Float.self).prefix(10)) }
        let encNonZero = encFloats.filter { abs($0) > 1e-6 }.count
        print("  🔍 Encoder 前10个值: \(encFloats.map { String(format: "%.4f", $0) }), 非零: \(encNonZero)/10")

        // ── 3. Decoder 自回归生成 ─────────────────────────────
        // 策略: 全程 use_cache_branch=false，避免量化模型中 If 节点 shape 相关崩溃
        // 每步传入完整 token 序列，logits 取最后一个位置

        // 3a. 准备常量
        let encAttentionMaskTensor = encMaskTensor // [1, maxLength]
        let useCacheTensor = try createBoolTensor(false) // 始终 false

        // 3b. 空 past_key_values（else_branch 不使用缓存，但模型仍需要输入）
        let emptyPastKVs = try createEmptyPastKeyValues()
        let pastKVInputNames = Self.pastKeyValueNames(prefix: "past_key_values")

        // 只取 logits 输出（不需要 present KV）
        let decoderOutputNames = Set<String>(["logits"])

        // 3c. 初始状态
        // NLLB 模型 decoder_start_token_id = 2 (</s>)
        // 训练时 decoder 输入: [</s>, tgt_lang_token, token_1, token_2, ...]
        // 推理时从 </s> 开始，由模型预测 tgt_lang_token 作为第一个输出
        let decoderStartTokenId: Int = 2  // </s>
        let tgtLangTokenId = tokenizer.decoderStartTokenId(for: targetLang)
        var generatedTokenIds: [Int] = [decoderStartTokenId]
        print("  🎯 Decoder start: </s>(2), target: \(tgtLangTokenId)(\(tokenizer.decode([tgtLangTokenId], skipSpecialTokens: false)))")

        print("  🔄 开始 Decoder 自回归生成 (无缓存模式)...")

        // vocabSize 将在 Step 0 从模型实际 logits 输出中推导
        var modelVocabSize: Int?

        for step in 0..<maxLength {
            // 每步传入完整已生成序列
            let decInputTensor = try createInt64Tensor(generatedTokenIds, shape: [1, generatedTokenIds.count])

            // 组装 decoder 全部输入
            var decoderInputs: [String: ORTValue] = [
                "input_ids": decInputTensor,
                "encoder_attention_mask": encAttentionMaskTensor,
                "encoder_hidden_states": encHiddenStates,
                "use_cache_branch": useCacheTensor,
            ]
            // 添加空 past_key_values（模型要求，但 else_branch 不使用）
            for name in pastKVInputNames {
                decoderInputs[name] = emptyPastKVs[name]!
            }

            // 运行 decoder
            let decoderOutputs: [String: ORTValue]
            do {
                decoderOutputs = try decoderSession.run(
                    withInputs: decoderInputs,
                    outputNames: decoderOutputNames,
                    runOptions: nil
                )
            } catch let e as NLLBTranslatorError { throw e }
            catch { throw NLLBTranslatorError.ortRunFailed("Decoder step \(step): \(error.localizedDescription)") }

            // 解析 logits → 取最后一个 token
            guard let logitsTensor = decoderOutputs["logits"] else {
                throw NLLBTranslatorError.ortRunFailed("Decoder 未输出 logits")
            }

            let logitsData = try logitsTensor.tensorData() as Data
            let logits = logitsData.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }

            // logits shape: [1, seq_len, model_vocab_size]
            let seqLen = generatedTokenIds.count

            // Step 0: 从实际 logits 推导模型词表大小（优先于 tokenizer.vocabSize）
            if modelVocabSize == nil {
                modelVocabSize = logits.count / seqLen
                print("  📊 模型词表大小: \(modelVocabSize!) (tokenizer: \(tokenizer.vocabSize))")
            }
            let vocabSize = modelVocabSize!
            let offset = (seqLen - 1) * vocabSize
            guard offset + vocabSize <= logits.count else {
                throw NLLBTranslatorError.ortRunFailed(
                    "Logits 越界: offset=\(offset) size=\(logits.count) vocab=\(vocabSize)"
                )
            }

            // Step 0 诊断：验证 logits 维度和词汇表大小是否匹配
            if step == 0 {
                print("  🔬 [Step 0] logitsData=\(logitsData.count) bytes, floatCount=\(logits.count)")
                print("  🔬 [Step 0] seqLen=\(seqLen) vocabSize=\(vocabSize) expected=\(seqLen * vocabSize)")
                let sampleRange = offset..<min(offset + 5, logits.count)
                let sample = sampleRange.map { logits[$0] }
                print("  🔬 [Step 0] 前5个logit: \(sample)")
            }

            // Argmax: 选出最高概率 token
            // 禁用特殊 token（pad=1, unk=3, bos=0）以免模型选到无意义 token
            let eosTokenId = 2
            let forbiddenTokens: Set<Int> = [0, 1, 3]
            var maxLogit: Float = -Float.infinity
            var nextTokenId: Int = eosTokenId
            for i in 0..<vocabSize {
                if forbiddenTokens.contains(i) { continue }
                if logits[offset + i] > maxLogit {
                    maxLogit = logits[offset + i]
                    nextTokenId = i
                }
            }

            // EOS 最少步数抑制：防止蒸馏模型过早终止
            if nextTokenId == eosTokenId && step < minNewTokens {
                // 找到第二好的非 EOS 非禁用 token
                var secondMaxLogit: Float = -Float.infinity
                var secondBestToken: Int = eosTokenId
                for i in 0..<vocabSize {
                    if i == eosTokenId || forbiddenTokens.contains(i) { continue }
                    if logits[offset + i] > secondMaxLogit {
                        secondMaxLogit = logits[offset + i]
                        secondBestToken = i
                    }
                }
                let tokenStr = tokenizer.decode([secondBestToken], skipSpecialTokens: false)
                print("  Step \(step): EOS 抑制 (需≥\(minNewTokens)), 改用 token \(secondBestToken)(\(tokenStr)) logit=\(String(format: "%.4f", secondMaxLogit))")
                nextTokenId = secondBestToken
            }

            // 检查终止条件
            if nextTokenId == eosTokenId {
                print("  ✓ Decoder EOS @ step \(step) (共 \(step) 步)")
                break
            }

            generatedTokenIds.append(nextTokenId)

            if step <= 5 {
                let tokenStr = tokenizer.decode([nextTokenId], skipSpecialTokens: false)
                print("  Step \(step): seq_len=\(seqLen) next_token=\(nextTokenId)(\(tokenStr)) max_logit=\(String(format: "%.4f", maxLogit))")
            }
        }

        print("  ✓ Decoder 完成: \(generatedTokenIds.count) tokens")

        // ── 4. Detokenize ────────────────────────────────────
        // generatedTokenIds: [</s>(2), tgt_lang, token_1, token_2, ..., eos]
        // 去掉 decoder start token 和 目标语言 token
        let outputTokenIds = Array(generatedTokenIds.dropFirst(2))
        let translatedText = tokenizer.decode(outputTokenIds, skipSpecialTokens: true)

        print("✅ 翻译完成: \"\(text.prefix(20))...\" → \"\(translatedText.prefix(40))...\"")
        return translatedText
    }

    // MARK: - Tensor Helpers

    /// 创建 Int64 张量
    private func createInt64Tensor(_ data: [Int], shape: [Int]) throws -> ORTValue {
        let int64Data = data.map { Int64($0) }
        let nsData = NSMutableData(
            bytes: int64Data,
            length: int64Data.count * MemoryLayout<Int64>.stride
        )
        let nsShape = shape.map { NSNumber(value: $0) }
        let tensor = try ORTValue(
            tensorData: nsData,
            elementType: .int64,
            shape: nsShape
        )
        return tensor
    }

    /// 创建 Float32 张量
    private func createFloatTensor(_ data: [Float], shape: [Int]) throws -> ORTValue {
        let nsData = NSMutableData(
            bytes: data,
            length: data.count * MemoryLayout<Float>.stride
        )
        let nsShape = shape.map { NSNumber(value: $0) }
        let tensor = try ORTValue(
            tensorData: nsData,
            elementType: .float,
            shape: nsShape
        )
        return tensor
    }

    /// 创建 Bool 标量张量 [1] (ONNX elem_type=9)
    private func createBoolTensor(_ value: Bool) throws -> ORTValue {
        var boolVal: Bool = value
        let nsData = NSMutableData(bytes: &boolVal, length: MemoryLayout<Bool>.stride)
        let shape: [NSNumber] = [1]
        let tensor = try ORTValue(
            tensorData: nsData,
            elementType: .bool,
            shape: shape
        )
        return tensor
    }

    /// 创建空的 past_key_value 张量 (shape [1, 16, 0, 64] — 0 元素)
    private func createEmptyPastKeyValue() throws -> ORTValue {
        let shape: [NSNumber] = [1, 16, 0, 64]
        // 空张量: 0 元素, 但 ORT 需要一个有效指针
        // 分配 4 字节 (1 float) 作为占位, ORT 会忽略数据因为 totalElements=0
        let dummyData = NSMutableData(length: MemoryLayout<Float>.stride)!
        let tensor = try ORTValue(
            tensorData: dummyData,
            elementType: .float,
            shape: shape
        )
        return tensor
    }

    /// 创建所有 48 个初始空 past_key_values
    private func createEmptyPastKeyValues() throws -> [String: ORTValue] {
        let names = Self.pastKeyValueNames(prefix: "past_key_values")
        var dict: [String: ORTValue] = [:]
        for name in names {
            dict[name] = try createEmptyPastKeyValue()
        }
        return dict
    }

    /// 调试用: 获取张量形状
    private func shapeString(_ tensor: ORTValue) -> String {
        guard let info = try? tensor.tensorTypeAndShapeInfo() else {
            return "?"
        }
        return "\(info.shape)"
    }

    // MARK: - Session Options

    private func createSessionOptions(optimizationLevel: ORTGraphOptimizationLevel) throws -> ORTSessionOptions {
        let options = try ORTSessionOptions()

        // 设置线程数
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        try? options.setIntraOpNumThreads(Int32(min(processorCount, 4)))

        // 图优化级别：Encoder 用 .all, Decoder 用 .basic (避免 QDQ 优化 crash)
        try? options.setGraphOptimizationLevel(optimizationLevel)

        return options
    }

    // MARK: - Cleanup

    func unload() {
        encoderSession = nil
        decoderSession = nil
        ortEnv = nil
        loadedModelName = nil
        DispatchQueue.main.async {
            self.isModelLoaded = false
            self.isTokenizerLoaded = false
        }
    }

    deinit {
        unload()
    }
}

// MARK: - Static Helpers

extension NLLBTranslator {
    /// 检查模型文件是否存在
    static func isModelAvailable(named modelName: String) -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let encPath = docs.appendingPathComponent("\(modelName)_encoder_quantized.onnx")
        let decPath = docs.appendingPathComponent("\(modelName)_decoder_quantized.onnx")
        let tokPath = docs.appendingPathComponent("\(modelName)_tokenizer.json")
        return FileManager.default.fileExists(atPath: encPath.path) &&
               FileManager.default.fileExists(atPath: decPath.path) &&
               FileManager.default.fileExists(atPath: tokPath.path)
    }
}
