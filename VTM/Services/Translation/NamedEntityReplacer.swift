//
//  NamedEntityReplacer.swift
//  VTM
//
//  专有名词预替换 — 解决 ML Kit 离线模型对中文音译专有名词的翻译问题
//  在翻译前将常见音译词替换为英文原名，翻译后再还原中文
//
//  例如: "哈利波特" → 预替换为 "Harry Potter" → ML Kit 保留 → 正确翻译
//

import Foundation

/// 专有名词替换器
/// 在 zh↔en 翻译中，对常见音译专有名词做双向替换
enum NamedEntityReplacer {

    // MARK: - 中文音译 → 英文原名（zh→en 翻译前使用）

    /// 常见中文音译词 → 英文原名的映射表
    /// 格式: [中文音译词: 英文原名]
    private static let chineseToEnglish: [(String, String)] = [
        // 影视/文学
        ("哈利波特", "Harry Potter"),
        ("哈利·波特", "Harry Potter"),
        ("赫敏", "Hermione"),
        ("罗恩", "Ron"),
        ("邓布利多", "Dumbledore"),
        ("伏地魔", "Voldemort"),
        ("蜘蛛侠", "Spider-Man"),
        ("蝙蝠侠", "Batman"),
        ("钢铁侠", "Iron Man"),
        ("美国队长", "Captain America"),
        ("黑寡妇", "Black Widow"),
        ("奇异博士", "Doctor Strange"),
        ("星球大战", "Star Wars"),
        ("权力的游戏", "Game of Thrones"),
        ("指环王", "Lord of the Rings"),
        ("霍比特人", "The Hobbit"),
        ("阿凡达", "Avatar"),
        ("变形金刚", "Transformers"),
        ("速度与激情", "Fast and Furious"),
        ("碟中谍", "Mission Impossible"),
        ("复仇者联盟", "The Avengers"),
        ("加勒比海盗", "Pirates of the Caribbean"),
        ("侏罗纪公园", "Jurassic Park"),
        ("黑客帝国", "The Matrix"),
        ("盗梦空间", "Inception"),
        ("星际穿越", "Interstellar"),
        ("泰坦尼克号", "Titanic"),
        ("冰雪奇缘", "Frozen"),
        ("疯狂动物城", "Zootopia"),
        ("寻梦环游记", "Coco"),
        ("狮子王", "The Lion King"),

        // 品牌/科技
        ("苹果公司", "Apple"),
        ("谷歌", "Google"),
        ("脸书", "Facebook"),
        ("特斯拉", "Tesla"),
        ("麦当劳", "McDonald's"),
        ("肯德基", "KFC"),
        ("星巴克", "Starbucks"),
        ("可口可乐", "Coca-Cola"),
        ("耐克", "Nike"),
        ("阿迪达斯", "Adidas"),

        // 城市/地名
        ("旧金山", "San Francisco"),
        ("洛杉矶", "Los Angeles"),
        ("纽约", "New York"),
        ("华盛顿", "Washington DC"),
        ("拉斯维加斯", "Las Vegas"),
        ("好莱坞", "Hollywood"),
        ("硅谷", "Silicon Valley"),
        ("华尔街", "Wall Street"),

        // 人物
        ("乔布斯", "Steve Jobs"),
        ("马斯克", "Elon Musk"),
        ("比尔盖茨", "Bill Gates"),
        ("奥巴马", "Obama"),
        ("特朗普", "Trump"),
        ("拜登", "Biden"),
        ("莎士比亚", "Shakespeare"),
        ("爱因斯坦", "Einstein"),
        ("牛顿", "Newton"),
        ("达尔文", "Darwin"),
        ("莫扎特", "Mozart"),
        ("贝多芬", "Beethoven"),
        ("毕加索", "Picasso"),
        ("梵高", "Van Gogh"),
        ("迈克尔乔丹", "Michael Jordan"),
        ("梅西", "Messi"),
        ("C罗", "Cristiano Ronaldo"),
    ]

    // MARK: - Public API

    /// 在 zh→en 翻译前，将中文音译词替换为英文原名
    /// 替换后的文本直接传给 ML Kit，ML Kit 会原样保留英文
    static func preReplaceForChineseToEnglish(_ text: String) -> String {
        var result = text
        for (chinese, english) in chineseToEnglish {
            result = result.replacingOccurrences(of: chinese, with: english)
        }
        if result != text {
            VTMLog.translation("🔤 专有名词预替换: \(text.prefix(40))... → \(result.prefix(40))...")
        }
        return result
    }
}
