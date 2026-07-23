//
//  HistoryView.swift
//  VTM
//
//  翻译历史页面 — 搜索、滑动删除、复制
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject private var strings = AppStrings.shared
    @StateObject private var historyManager = TranslationHistoryManager.shared
    @State private var searchText = ""
    @State private var showClearConfirm = false

    private var filteredRecords: [TranslationRecord] {
        if searchText.isEmpty {
            return historyManager.records
        }
        return historyManager.records.filter { record in
            record.sourceText.localizedCaseInsensitiveContains(searchText) ||
            record.translatedText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if historyManager.records.isEmpty {
                emptyState
            } else {
                recordList
            }
        }
        .navigationTitle(Text(L10n: "翻译历史"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索翻译记录")
        .toolbar {
            if !historyManager.records.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("清空") {
                        showClearConfirm = true
                    }
                    .font(.subheadline)
                }
            }
        }
        .alert(AppStrings.shared.get("清空历史"), isPresented: $showClearConfirm) {
            Button(AppStrings.shared.get("取消"), role: .cancel) { }
            Button(AppStrings.shared.get("确认清空"), role: .destructive) {
                withAnimation {
                    historyManager.clearAll()
                }
            }
        } message: {
            Text(String(format: AppStrings.shared.get("将删除全部 %d 条翻译记录，此操作不可撤销。"), historyManager.records.count))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.top, 60)

            Text(L10n: "暂无翻译记录")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L10n: "翻译后会自动保存在这里")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Record List

    private var recordList: some View {
        List {
            ForEach(filteredRecords) { record in
                historyRow(record)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                historyManager.deleteRecord(record)
                            }
                        } label: {
                            Label(L10n: "删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            UIPasteboard.general.string = record.translatedText
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } label: {
                            Label(L10n: "复制译文", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - History Row

    private func historyRow(_ record: TranslationRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 语言对 + 时间
            HStack {
                (Text(LocalizedStringKey(Translator.displayName(for: record.sourceLanguage))) + Text(" → ") + Text(LocalizedStringKey(Translator.displayName(for: record.targetLanguage))))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.adaptiveBlueTranslucent)
                    )

                Spacer()

                Text(record.relativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 原文
            Text(record.sourceText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

            // 译文
            Text(record.translatedText)
                .font(.subheadline)
                .foregroundColor(.green)
                .lineLimit(2)
                .padding(.leading, 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
