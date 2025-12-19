//
//  InstructionStep.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.appPurple)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.textGray)
        }
    }
}