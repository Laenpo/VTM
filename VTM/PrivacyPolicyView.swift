//
//  PrivacyPolicyView.swift
//  VTM
//
//  Created by 张恒郡 on 2026-05-11.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @ObservedObject private var strings = AppStrings.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题
                    Text(L10n: "隐私政策")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text(L10n: "最后更新日期：2026年5月11日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // 引言
                    PolicySectionView(title: "引言", content: "VTM（以下简称\"我们\"）非常重视您的隐私保护。本隐私政策说明了我们如何收集、使用、存储和保护您的个人信息。使用本应用即表示您同意本政策的条款。")
                    
                    // 信息收集
                    PolicySectionView(title: "信息收集", content: """
                    我们可能收集以下信息：
                    
                    1. 语音数据：当您使用语音翻译功能时，我们会录制并处理您的语音。
                    
                    2. 设备信息：我们收集设备类型、操作系统版本、唯一设备标识符等信息以优化应用性能。
                    
                    3. 使用数据：我们收集应用使用统计信息，以改进我们的服务。
                    
                    4. 翻译历史：如果您选择保存翻译历史，相关翻译记录将存储在您的设备上。
                    """)
                    
                    // 信息使用
                    PolicySectionView(title: "信息使用", content: """
                    我们使用收集的信息用于以下目的：
                    
                    1. 提供、维护和改进我们的翻译服务。
                    
                    2. 处理您的语音输入并进行翻译。
                    
                    3. 开发新功能和服务。
                    
                    4. 保护我们的服务和用户。
                    """)
                    
                    // 信息共享
                    PolicySectionView(title: "信息共享", content: """
                    我们不会出售您的个人信息。我们可能在以下情况下共享您的信息：
                    
                    1. 经您同意：在您同意的情况下，我们可能与第三方共享您的信息。
                    
                    2. 服务提供商：我们可能与帮助我们从事实翻译服务的服务提供商共享信息。
                    
                    3. 法律要求：如果法律要求或为了保护我们的权利，我们可能会披露您的信息。
                    """)
                    
                    // 数据安全
                    PolicySectionView(title: "数据安全", content: "我们采取合理措施保护您的信息免受未经授权的访问、使用或披露。但请注意，互联网传输或电子存储方法并不完全安全，我们无法保证绝对安全。")
                    
                    // 您的权利
                    PolicySectionView(title: "您的权利", content: """
                    根据适用法律，您可能拥有以下权利：
                    
                    1. 访问您的个人信息。
                    
                    2. 更正不准确的信息。
                    
                    3. 删除您的个人信息。
                    
                    4. 撤回同意。
                    
                    5. 数据可携带性。
                    
                    要行使这些权利，请通过以下联系方式与我们联系。
                    """)
                    
                    // 儿童隐私
                    PolicySectionView(title: "儿童隐私", content: "我们的服务不面向13岁以下的儿童。我们不会故意收集13岁以下儿童的个人信息。如果我们发现收集了13岁以下儿童的个人信息，我们将采取措施删除该信息。")
                    
                    // 政策更新
                    PolicySectionView(title: "政策更新", content: "我们可能会不时更新本隐私政策。我们会通过应用内通知或更新日期的方式通知您任何重大变更。建议您定期查看本政策以了解最新信息。")
                    
                    // 联系我们
                    PolicySectionView(title: "联系我们", content: "如果您对本隐私政策有任何疑问或关切，请通过以下方式联系我们：\n\n邮箱：azhang364@gmail.com")
                    
                    Spacer(minLength: 30)
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationTitle(Text(L10n: "隐私政策"))
            .navigationBarItems(trailing:
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 使用条款视图
struct TermsOfServiceView: View {
    @ObservedObject private var strings = AppStrings.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n: "使用条款")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text(L10n: "最后更新日期：2026年5月11日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    PolicySectionView(title: "接受条款", content: "通过使用 VTM 应用（以下简称\"应用\"），您同意受本使用条款的约束。如果您不同意本条款的任何部分，请勿使用本应用。")
                    
                    PolicySectionView(title: "服务描述", content: "VTM 是一款语音翻译应用，允许用户通过语音输入进行实时翻译。我们保留随时修改或终止服务的权利，无需事先通知。")
                    
                    PolicySectionView(title: "用户责任", content: """
                    您同意：
                    
                    1. 不将本应用用于任何非法目的。
                    
                    2. 不干扰或破坏应用的正常运行。
                    
                    3. 不尝试未经授权访问我们的系统或网络。
                    
                    4. 对您使用本应用的行为承担全部责任。
                    """)
                    
                    PolicySectionView(title: "知识产权", content: "本应用及其所有内容、功能和特性（包括所有知识产权）均为我们或我们的许可方的财产。未经我们明确书面许可，您不得复制、修改、分发或创建衍生作品。")
                    
                    PolicySectionView(title: "免责声明", content: "本应用按\"原样\"和\"可用\"基础提供。我们不保证应用的不间断、及时、安全或无错误运行。对于因使用或无法使用本应用而导致的任何损失或损害，我们不承担任何责任。")
                    
                    PolicySectionView(title: "条款修改", content: "我们保留随时修改本使用条款的权利。修改后的条款将在应用内发布。您继续使用本应用即表示您接受修改后的条款。")
                    
                    PolicySectionView(title: "联系我们", content: "如果您对本使用条款有任何疑问，请通过以下方式联系我们：\n\n邮箱：azhang364@gmail.com")
                    
                    Spacer(minLength: 30)
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationTitle(Text(L10n: "使用条款"))
            .navigationBarItems(trailing:
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 政策段落视图
struct PolicySectionView: View {
    @ObservedObject private var strings = AppStrings.shared
    let title: LocalizedStringKey
    let content: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
