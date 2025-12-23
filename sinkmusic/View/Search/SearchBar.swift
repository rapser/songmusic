//
//  SearchBar.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "¿Qué quieres escuchar?"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textGray)
                .font(.system(size: 16))

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textGray))
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textGray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appGray)
        .cornerRadius(10)
    }
}
