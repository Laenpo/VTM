//
//  Bundle+LanguageSwitching.swift
//  VTM
//
//  动态语言切换 — method swizzling Bundle.localizedString
//  使 Text(L10n: "中文") 在运行时跟随 appLanguage 偏好
//

import Foundation

extension Bundle {

    // MARK: - Swizzle 状态

    private static var isSwizzled = false

    /// 在 VTMApp.init() 中调用一次
    static func enableLanguageSwitching() {
        guard !isSwizzled else { return }
        isSwizzled = true

        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.vtm_localizedString(forKey:value:table:))

        guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else {
            print("⚠️ Bundle swizzle failed")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        print("✅ Bundle language switching enabled")
    }

    // MARK: - Swizzled 实现

    /// 替代 localizedString(forKey:value:table:)
    /// 根据 appLanguage 动态选择 .lproj bundle
    @objc private func vtm_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // 只劫持 main bundle 的查询；子 bundle（如语言 .lproj）走原始逻辑
        guard self == Bundle.main else {
            return self.vtm_localizedString(forKey: key, value: value, table: tableName)
        }

        // 读取用户偏好语言，未设置则用 zh-Hans
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans"

        // 尝试加载该语言的 .lproj bundle
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let langBundle = Bundle(path: path) else {
            // 回退到原始实现
            return self.vtm_localizedString(forKey: key, value: value, table: tableName)
        }

        // 用语言 bundle 查询翻译（走原始逻辑，因为我们只在 main bundle 时拦截）
        return langBundle.vtm_localizedString(forKey: key, value: value, table: tableName)
    }
}
