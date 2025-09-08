//
//  ScrollOffsetPreferenceKey.swift
//  sinkmusic
//
//  Created by miguel tomairo on 7/09/25.
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
