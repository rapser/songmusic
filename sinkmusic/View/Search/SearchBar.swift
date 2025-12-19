//
//  SearchBar.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textGray)

            TextField("", text: $text, prompt: Text("¿Qué quieres escuchar?").foregroundColor(.textGray))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textGray)
                }
            }
        }
        .padding(12)
        .background(Color.appGray)
        .cornerRadius(8)
    }
}
