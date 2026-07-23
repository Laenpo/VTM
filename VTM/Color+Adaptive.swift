//
//  Color+Adaptive.swift
//  VTM
//
//  动态颜色 — 自动适配浅色 / 深色模式
//

import SwiftUI

extension Color {
    // MARK: - 半透明背景色（深色模式下提高不透明度以保证可见性）

    /// 蓝色半透明背景 (light: 0.10 / dark: 0.22)
    static let adaptiveBlueTranslucent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemBlue.withAlphaComponent(0.22)
            : UIColor.systemBlue.withAlphaComponent(0.10)
    })

    /// 绿色半透明背景 (light: 0.08 / dark: 0.18)
    static let adaptiveGreenTranslucent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemGreen.withAlphaComponent(0.18)
            : UIColor.systemGreen.withAlphaComponent(0.08)
    })

    /// 绿色中等半透明 (light: 0.10 / dark: 0.22)
    static let adaptiveGreenMedium = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemGreen.withAlphaComponent(0.22)
            : UIColor.systemGreen.withAlphaComponent(0.10)
    })

    /// 引擎状态 Chip 背景 (light: 0.12 / dark: 0.22)
    static func adaptiveChipBg(base: Color, lightAlpha: CGFloat = 0.12, darkAlpha: CGFloat = 0.22) -> Color {
        Color(uiColor: UIColor { trait in
            let uiColor = UIColor(base)
            return trait.userInterfaceStyle == .dark
                ? uiColor.withAlphaComponent(darkAlpha)
                : uiColor.withAlphaComponent(lightAlpha)
        })
    }

    /// 引擎状态 Chip 边框 (light: 0.30 / dark: 0.45)
    static func adaptiveChipBorder(base: Color, lightAlpha: CGFloat = 0.30, darkAlpha: CGFloat = 0.45) -> Color {
        Color(uiColor: UIColor { trait in
            let uiColor = UIColor(base)
            return trait.userInterfaceStyle == .dark
                ? uiColor.withAlphaComponent(darkAlpha)
                : uiColor.withAlphaComponent(lightAlpha)
        })
    }

    /// Toast 浮层背景 — 白色文字需要深色底，但深色模式下需略亮以区分背景
    static let adaptiveToastBg = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.25, alpha: 0.92)
            : UIColor.black.withAlphaComponent(0.75)
    })

    /// 卡片背景 (light: gray 5% / dark: white 8%)
    static let adaptiveCardBg = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.gray.withAlphaComponent(0.05)
    })

    /// ModelManagementView 网络指示器背景
    static let adaptiveOrangeTranslucent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemOrange.withAlphaComponent(0.22)
            : UIColor.systemOrange.withAlphaComponent(0.10)
    })
}
