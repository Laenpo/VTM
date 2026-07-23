//
//  LegalView.swift
//  VTM
//
//  合并法律信息：隐私政策 + 使用条款 + 开源许可
//  Segmented 切换
//

import SwiftUI

struct LegalView: View {
    @ObservedObject private var strings = AppStrings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: LegalSection = .privacy

    enum LegalSection: String, CaseIterable {
        case privacy
        case terms
        case licenses

        var title: String {
            switch self {
            case .privacy:  return AppStrings.shared.get("隐私政策")
            case .terms:    return AppStrings.shared.get("使用条款")
            case .licenses: return AppStrings.shared.get("开源许可")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 下拉指示条 (Grab Handle)
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Segmented 切换器
            Picker("", selection: $selectedSection) {
                ForEach(LegalSection.allCases, id: \.self) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedSection == .privacy {
                        privacyContent
                    } else if selectedSection == .terms {
                        termsContent
                    } else {
                        licensesContent
                    }

                    // 联系信息 (Privacy & Terms only)
                    if selectedSection != .licenses {
                        Divider()
                            .padding(.top, 8)
                        contactSection
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(Text(L10n: "法律信息"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(AppStrings.shared.get("关闭")) { dismiss() }
            }
        }
    }

    // MARK: - 隐私政策

    @ViewBuilder
    private var privacyContent: some View {
        Text(L10n: "最后更新日期：2026年5月11日")
            .font(.caption)
            .foregroundColor(.secondary)

        policySection(title: "引言", content: "VTM 是一款完全离线的语音翻译应用。本隐私政策说明了我们如何处理您的数据。使用本应用即表示您同意本政策的条款。")

        policySection(title: "数据收集与使用", content: "VTM 的核心理念是离线隐私保护：\n\n1. 语音数据：所有语音识别和处理均在您的设备本地完成，不会上传至任何服务器。\n\n2. 翻译历史：如果您选择保存翻译历史，相关记录仅存储在您的设备上，您可以随时删除。\n\n3. 模型下载：VTM 仅在下载翻译模型时需要网络连接，下载过程传输的是模型文件，不包含任何个人数据。\n\n4. 我们不会收集、出售或与任何第三方共享您的个人信息。")

        policySection(title: "数据存储", content: "您的所有数据（语音、翻译记录、设置偏好）均仅存储在您的设备本地。VTM 不使用任何云端存储服务。卸载应用将永久删除所有数据。")

        policySection(title: "数据安全", content: "因为所有数据均在设备本地处理且不连接互联网，您的数据安全由您的设备本身保障。我们无法访问、也不存储您的任何个人数据。")

        policySection(title: "您的权利", content: "您可以随时：\n\n1. 在设备设置中撤销麦克风权限\n\n2. 在应用中删除翻译历史\n\n3. 卸载应用以永久删除所有数据\n\n如有任何隐私问题，请通过以下联系方式与我们联系。")

        policySection(title: "政策更新", content: "我们可能会不时更新本隐私政策。我们会通过应用内通知的方式告知您任何重大变更。建议您定期查看本政策以了解最新信息。")
    }

    // MARK: - 使用条款

    @ViewBuilder
    private var termsContent: some View {
        Text(L10n: "最后更新日期：2026年5月11日")
            .font(.caption)
            .foregroundColor(.secondary)

        policySection(title: "接受条款", content: "通过使用 VTM 应用（以下简称\"应用\"），您同意受本使用条款的约束。如果您不同意本条款的任何部分，请勿使用本应用。")

        policySection(title: "服务描述", content: "VTM 是一款语音翻译应用，允许用户通过语音输入进行实时翻译。我们保留随时修改或终止服务的权利，无需事先通知。")

        policySection(title: "用户责任", content: "您同意：\n\n1. 不将本应用用于任何非法目的。\n\n2. 不干扰或破坏应用的正常运行。\n\n3. 不尝试未经授权访问我们的系统或网络。\n\n4. 对您使用本应用的行为承担全部责任。")

        policySection(title: "知识产权", content: "本应用及其所有内容、功能和特性（包括所有知识产权）均为我们或我们的许可方的财产。未经我们明确书面许可，您不得复制、修改、分发或创建衍生作品。")

        policySection(title: "免责声明", content: "本应用按\"原样\"和\"可用\"基础提供。我们不保证应用的不间断、及时、安全或无错误运行。对于因使用或无法使用本应用而导致的任何损失或损害，我们不承担任何责任。")

        policySection(title: "条款修改", content: "我们保留随时修改本使用条款的权利。修改后的条款将在应用内发布。您继续使用本应用即表示您接受修改后的条款。")
    }

    // MARK: - 共享联系方式
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            policySection(title: "联系我们", content: "如果您对本隐私政策或使用条款有任何疑问，请通过以下方式联系我们：")
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n: "邮箱：azhang364@gmail.com")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(L10n: "公司网站：https://www.3dtobe.com/VTM")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 开源许可
    private var licensesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n: "VTM 使用了以下开源组件。感谢所有开源贡献者。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LicenseItem(name: "Whisper.cpp", license: "MIT", copyright: "Copyright © 2023-2026 The ggml authors", url: "https://github.com/ggerganov/whisper.cpp")
            LicenseItem(name: "ONNX Runtime", license: "MIT", copyright: "Copyright © Microsoft Corporation", url: "https://github.com/microsoft/onnxruntime")
            LicenseItem(name: "SSZipArchive", license: "MIT", copyright: "Copyright © 2013-2021 ZipArchive", url: "https://github.com/ZipArchive/ZipArchive")
            LicenseItem(name: "Google ML Kit", license: "Apache 2.0", copyright: "Copyright © Google LLC", url: "https://developers.google.com/ml-kit")
            LicenseItem(name: "GoogleDataTransport", license: "Apache 2.0", copyright: "Copyright © Google LLC", url: "")
            LicenseItem(name: "GoogleToolboxForMac", license: "Apache 2.0", copyright: "Copyright © Google LLC", url: "")
            LicenseItem(name: "GoogleUtilities", license: "Apache 2.0", copyright: "Copyright © Google LLC", url: "")
            LicenseItem(name: "GTMSessionFetcher", license: "Apache 2.0", copyright: "Copyright © Google LLC", url: "")
            LicenseItem(name: "PromisesObjC", license: "Apache 2.0", copyright: "Copyright © Google LLC", url: "")
            LicenseItem(name: "nanopb", license: "zlib-style", copyright: "Copyright © 2011 Petteri Aimonen", url: "https://github.com/nanopb/nanopb")
        }
    }

    // MARK: - License Item
    private struct LicenseItem: View {
        let name: String
        let license: String
        let copyright: String
        let url: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: name)
                    .font(.headline)
                Text(verbatim: "\(license)  |  \(copyright)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !url.isEmpty {
                    Text(verbatim: url)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - 章节组件
    private func policySection(title key_title: String, content key_content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n: key_title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(L10n: key_content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }
}

#Preview {
    NavigationStack {
        LegalView()
    }
}
