//
//  L10nExtensions.swift
//  VTM
//
//  Text / Label convenience initializers for AppStrings-based localization
//

import SwiftUI

extension Text {
    init(L10n key: String) {
        self.init(verbatim: AppStrings.shared.get(key))
    }
}

extension Label where Title == Text, Icon == Image {
    init(L10n key: String, systemImage: String) {
        self.init(title: { Text(L10n: key) }, icon: { Image(systemName: systemImage) })
    }
}
