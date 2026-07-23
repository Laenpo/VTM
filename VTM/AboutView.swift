//
//  AboutView.swift
//  VTM
//
//  关于页面：Logo、版本、开发者、功能特性
//

import SwiftUI

struct AboutView: View {
    @ObservedObject private var strings = AppStrings.shared
    @Environment(\.presentationMode) var presentationMode

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (Build \(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Logo + 名称
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue, .blue.opacity(0.3))

                        Text("VTM")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Voice Translation Mate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(verbatim: "VTM \(versionString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    // MARK: - 开发者信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n: "开发者信息")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            infoRow(icon: "building.2", label: "公司", value: "三维天工 (3dtobe)")
                            Divider().padding(.leading, 56)
                            infoRow(icon: "person", label: "开发者", value: "张恒郡")
                            Divider().padding(.leading, 56)
                            infoRow(icon: "envelope", label: "邮箱", value: "azhang364@gmail.com")
                            Divider().padding(.leading, 56)
                            infoRow(icon: "envelope", label: "反馈", value: "通过电话直接联系")
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // MARK: - 项目介绍
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n: "项目介绍")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n: "VTM (Voice Translation Mate) 是一款完全离线的语音翻译工具，支持实时语音识别、多语言翻译和语音合成。无需网络连接，所有数据处理均在本地完成，确保隐私安全。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // MARK: - 功能特性
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n: "核心特性")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 10) {
                            featureRow(icon: "wifi.slash", text: "完全离线，无需网络连接")
                            featureRow(icon: "bolt.shield", text: "隐私安全，数据不离开设备")
                            featureRow(icon: "translate", text: "多语言支持（中英日韩等）")
                            featureRow(icon: "mic", text: "实时语音识别与翻译")
                            featureRow(icon: "play.circle", text: "自动播放翻译结果")
                            featureRow(icon: "square.grid.2x2", text: "模型管理（WiFi 下载推荐）")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // MARK: - 版权
                    VStack(spacing: 4) {
                        Text(L10n: "© 2026 三维天工 (3dtobe)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(L10n: "VTM — 离线语音翻译 · SwiftUI + whisper.cpp")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(Text(L10n: "关于"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Components

    private func infoRow(icon: String, label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func techRow(icon: String, name: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    AboutView()
}
