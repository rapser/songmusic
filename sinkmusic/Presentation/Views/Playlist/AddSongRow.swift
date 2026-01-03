//
//  AddSongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//


import SwiftUI
import SwiftData

struct AddSongRow: View {
    let song: SongEntity
    let onAdd: () -> Void
    
    @State private var wasAdded = false
    @State private var artworkImage: UIImage?

    var body: some View {
        HStack {
            Group {
                if let image = artworkImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.appGray
                        .overlay(Image(systemName: "music.note").foregroundColor(.textGray))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear(perform: loadImage)
            
            VStack(alignment: .leading) {
                Text(song.title).foregroundColor(.white).lineLimit(1)
                Text(song.artist).foregroundColor(.textGray).font(.caption).lineLimit(1)
            }
            
            Spacer()
            
            if wasAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appPurple)
                    .font(.title2)
            } else {
                Button(action: {
                    onAdd()
                    withAnimation {
                        wasAdded = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.appPurple)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func loadImage() {
        guard artworkImage == nil else { return }
        if let data = song.artworkThumbnail {
            self.artworkImage = UIImage(data: data)
        }
    }
}