//
//  NLLBTokenizer.swift
//  VTM
//
//  SentencePiece BPE Tokenizer for NLLB-200
//  - 解析 HuggingFace tokenizer.json
//  - FLORES-200 语言代码前缀
//  - 最长前缀 BPE 分词
//

import Foundation

// MARK: - FLORES-200 Language Codes

/// NLLB-200 支持的 FLORES-200 语言代码
enum NLLBLanguage: String, CaseIterable {
    case chineseSimplified = "zho_Hans"
    case chineseTraditional = "zho_Hant"
    case english = "eng_Latn"
    case japanese = "jpn_Jpan"
    case korean = "kor_Hang"
    case french = "fra_Latn"
    case spanish = "spa_Latn"
    case german = "deu_Latn"
    case russian = "rus_Cyrl"
    case arabic = "arb_Arab"
    case portuguese = "por_Latn"
    case italian = "ita_Latn"
    case thai = "tha_Thai"
    case vietnamese = "vie_Latn"
    case hindi = "hin_Deva"
    case turkish = "tur_Latn"

    /// 从 BCP-47 语言代码映射
    static func fromBCP47(_ code: String) -> NLLBLanguage {
        switch code {
        case "zh", "zh-Hans", "zh-CN": return .chineseSimplified
        case "zh-Hant", "zh-TW", "zh-HK": return .chineseTraditional
        case "en": return .english
        case "ja": return .japanese
        case "ko": return .korean
        case "fr": return .french
        case "es": return .spanish
        case "de": return .german
        case "ru": return .russian
        case "ar": return .arabic
        case "pt": return .portuguese
        case "it": return .italian
        case "th": return .thai
        case "vi": return .vietnamese
        case "hi": return .hindi
        case "tr": return .turkish
        default: return .english
        }
    }
}

// MARK: - Tokenizer Error

enum TokenizerError: Error, LocalizedError {
    case modelNotLoaded
    case tokenNotFound(String)
    case invalidVocabulary
    case encodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "分词器模型未加载"
        case .tokenNotFound(let token):
            return "词表中未找到 token: \(token)"
        case .invalidVocabulary:
            return "词表数据无效"
        case .encodeFailed(let reason):
            return "分词失败: \(reason)"
        }
    }
}

// MARK: - NLLBTokenizer

final class NLLBTokenizer {
    // MARK: - Properties

    private var tokenToId: [String: Int] = [:]
    private var idToToken: [Int: String] = [:]

    /// 特殊 token
    private var bosToken: String = "<s>"
    private var eosToken: String = "</s>"
    private var padToken: String = "<pad>"
    private var unkToken: String = "<unk>"

    private var bosTokenId: Int = 0
    private var eosTokenId: Int = 2
    private var padTokenId: Int = 1
    private var unkTokenId: Int = 3

    /// 语言代码对应的 token ID
    private var langTokenIds: [NLLBLanguage: Int] = [:]

    /// 源语言和目标语言
    var sourceLanguage: NLLBLanguage = .chineseSimplified
    var targetLanguage: NLLBLanguage = .english

    var isLoaded: Bool { !tokenToId.isEmpty }

    /// 当前词表大小（用于 ONNX 模型 logits 解析）
    var vocabSize: Int { tokenToId.count }

    // MARK: - Init

    init() {}

    // MARK: - Load Tokenizer

    /// 从 tokenizer.json 文件加载词表
    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let model = json?["model"] as? [String: Any],
              let vocab = model["vocab"] as? [String: Int] else {
            throw TokenizerError.invalidVocabulary
        }

        tokenToId = vocab
        idToToken = Dictionary(uniqueKeysWithValues: vocab.map { ($1, $0) })

        // 读取特殊 token
        if let addedTokens = json?["added_tokens"] as? [[String: Any]] {
            for token in addedTokens {
                guard let content = token["content"] as? String,
                      let id = token["id"] as? Int else { continue }
                tokenToId[content] = id
                idToToken[id] = content
            }
        }

        // 初始化特殊 token ID
        bosTokenId = tokenToId[bosToken] ?? 0
        eosTokenId = tokenToId[eosToken] ?? 2
        padTokenId = tokenToId[padToken] ?? 1
        unkTokenId = tokenToId[unkToken] ?? 3

        // 缓存语言 token ID（Xenova tokenizer 使用裸 FLORES 代码，不带 __ 前后缀）
        var foundLangTokens = 0
        for lang in NLLBLanguage.allCases {
            // 尝试双下划线格式（标准 NLLB），然后裸格式（Xenova 导出）
            let langTokenWithMarker = "__\(lang.rawValue)__"
            let langTokenBare = lang.rawValue
            langTokenIds[lang] = tokenToId[langTokenWithMarker] ?? tokenToId[langTokenBare]
            if langTokenIds[lang] != nil {
                foundLangTokens += 1
            }
        }
        print("  🌐 语言 token: \(foundLangTokens)/\(NLLBLanguage.allCases.count) 个已解析")

        print("✅ NLLB Tokenizer 加载完成 — 词表大小: \(tokenToId.count)")
    }

    // MARK: - Encoding

    /// 将文本编码为 token ID 序列
    /// NLLB 输入格式: [source_lang_token] + tokenized_text + [eos] + [target_lang_token]
    func encode(
        text: String,
        sourceLang: NLLBLanguage,
        targetLang: NLLBLanguage,
        maxLength: Int = 128
    ) throws -> [Int] {
        guard isLoaded else { throw TokenizerError.modelNotLoaded }

        // 1. 源语言 token
        let srcLangToken = langTokenIds[sourceLang] ?? unkTokenId

        // 2. 分词
        let tokens = tokenize(text, maxLength: maxLength - 3) // 预留空间给 lang tokens + eos

        // 3. 目标语言 token (放在末尾，用于 forced decoding)
        let tgtLangToken = langTokenIds[targetLang] ?? unkTokenId

        // 4. 组装: [source_lang, tokens..., eos, target_lang]
        var inputIds: [Int] = [srcLangToken]
        inputIds.append(contentsOf: tokens)
        inputIds.append(eosTokenId)
        inputIds.append(tgtLangToken)

        // 诊断：显示编码结果
        print("  📝 Encode: src_lang=\(srcLangToken) tokens=\(tokens.count) → [\(inputIds.prefix(3).map(String.init).joined(separator: ", "))...\(inputIds.suffix(2).map(String.init).joined(separator: ", "))] (共\(inputIds.count)个)")

        return inputIds
    }

    /// 用于 decoder input (forced BOS token)
    func decoderStartTokenId(for language: NLLBLanguage) -> Int {
        return langTokenIds[language] ?? unkTokenId
    }

    // MARK: - Decoding

    /// 将 token ID 序列解码为文本
    func decode(_ tokenIds: [Int], skipSpecialTokens: Bool = true) -> String {
        guard isLoaded else { return "" }

        var result = ""
        for id in tokenIds {
            guard let token = idToToken[id] else { continue }

            // 跳过特殊 token
            if skipSpecialTokens {
                if id == padTokenId || id == eosTokenId || id == bosTokenId {
                    continue
                }
                // 跳过语言 token (__xxx__ 或裸 FLORES 代码 xxx_Xxxx)
                if token.hasPrefix("__") && token.hasSuffix("__") {
                    continue
                }
                // 检测裸 FLORES 代码格式（如 eng_Latn）
                let floreRegex = try? NSRegularExpression(pattern: "^[a-z]{3}_[A-Z][a-z]{3}$")
                let range = NSRange(token.startIndex..., in: token)
                if floreRegex?.firstMatch(in: token, range: range) != nil {
                    continue
                }
            }

            // SentencePiece 使用 ▁ (U+2581) 表示词首空格
            if token.hasPrefix("▁") {
                result += " " + String(token.dropFirst())
            } else {
                result += token
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private: BPE Tokenization

    /// 基于词表的最长前缀匹配分词
    private func tokenize(_ text: String, maxLength: Int) -> [Int] {
        // 预处理: 小写 + 添加词首标记
        let normalized = text.lowercased()
        let preprocessed = "▁" + normalized.replacingOccurrences(of: " ", with: " ▁")

        var tokenIds: [Int] = []
        var remaining = preprocessed[...]

        while !remaining.isEmpty && tokenIds.count < maxLength {
            var matched = false

            // 最长前缀匹配
            for len in stride(from: min(remaining.count, 20), through: 1, by: -1) {
                let candidate = String(remaining.prefix(len))
                if let id = tokenToId[candidate] {
                    tokenIds.append(id)
                    remaining = remaining.dropFirst(len)
                    matched = true
                    break
                }
            }

            if !matched {
                // 退回到字符级
                let char = String(remaining.prefix(1))
                tokenIds.append(tokenToId[char] ?? unkTokenId)
                remaining = remaining.dropFirst()
            }
        }

        return tokenIds
    }

    // MARK: - Attention Mask

    /// 生成 attention mask (1 表示有效 token, 0 表示 padding)
    static func createAttentionMask(tokenIds: [Int], padTokenId: Int = 1, totalLength: Int? = nil) -> [Int64] {
        let length = totalLength ?? tokenIds.count
        var mask = [Int64](repeating: 0, count: length)
        for i in 0..<min(tokenIds.count, length) {
            mask[i] = 1
        }
        return mask
    }

    // MARK: - Padding

    /// 将 token IDs 填充到指定长度
    func pad(_ tokenIds: [Int], toLength length: Int) -> [Int] {
        if tokenIds.count >= length { return Array(tokenIds.prefix(length)) }
        return tokenIds + Array(repeating: padTokenId, count: length - tokenIds.count)
    }
}

// MARK: - Helper: Download & Cache

extension NLLBTokenizer {
    /// tokenizer.json 的 HuggingFace URL (forkjoin-ai ONNX 模型)
    static func tokenizerURL(for modelName: String) -> String {
        return "https://huggingface.co/forkjoin-ai/\(modelName)/resolve/main/tokenizer.json"
    }

    /// 本地存储路径
    static func localTokenizerPath(for modelName: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("\(modelName)_tokenizer.json")
    }
}
