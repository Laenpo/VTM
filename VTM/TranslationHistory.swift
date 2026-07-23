//
//  TranslationHistory.swift
//  VTM
//
//  翻译历史管理器 — 本地 UserDefaults 存储，最多 50 条
//

import Foundation
import Combine

// MARK: - TranslationRecord

/// 单条翻译记录（Codable，适合 UserDefaults JSON 存储）
struct TranslationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date

    init(sourceText: String, translatedText: String, sourceLanguage: String, targetLanguage: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
    }

    /// 相对时间描述（如"刚刚"、"5 分钟前"）
    var relativeTime: String {
        let interval = -timestamp.timeIntervalSinceNow
        switch interval {
        case ..<60:
            return "刚刚"
        case ..<3600:
            return "\(Int(interval / 60)) 分钟前"
        case ..<86400:
            return "\(Int(interval / 3600)) 小时前"
        case ..<604800:
            return "\(Int(interval / 86400)) 天前"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }

    var languagePair: String {
        "\(Translator.displayName(for: sourceLanguage)) → \(Translator.displayName(for: targetLanguage))"
    }
}

// MARK: - TranslationHistoryManager

/// 翻译历史管理器 — ObservableObject 单例
/// 存储策略：UserDefaults JSON 编码，最多 50 条，FIFO 淘汰
final class TranslationHistoryManager: ObservableObject {
    static let shared = TranslationHistoryManager()

    private let maxRecords = 50
    private let storageKey = "com.vtm.translationHistory"

    @Published private(set) var records: [TranslationRecord] = []

    private init() {
        loadFromStorage()
    }

    // MARK: - Public API

    /// 添加一条翻译记录（自动裁剪到 50 条）
    func addRecord(sourceText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        let record = TranslationRecord(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        records.insert(record, at: 0)

        // FIFO 裁剪
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        saveToStorage()
    }

    /// 删除指定记录
    func deleteRecord(_ record: TranslationRecord) {
        records.removeAll { $0.id == record.id }
        saveToStorage()
    }

    /// 清空所有历史
    func clearAll() {
        records.removeAll()
        saveToStorage()
    }

    // MARK: - Storage

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            records = []
            return
        }
        do {
            records = try JSONDecoder().decode([TranslationRecord].self, from: data)
        } catch {
            print("⚠️ 翻译历史加载失败: \(error.localizedDescription)")
            records = []
        }
    }

    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ 翻译历史保存失败: \(error.localizedDescription)")
        }
    }
}
