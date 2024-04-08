//
//  TextView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 04/04/2024.
//

import SwiftUI

struct TextView: View {
    @Binding var text: String
    @Binding var textSize: CGSize
    @State private var dragOffset: CGSize = .zero
    @Binding var textLocation: CGPoint
    @State private var isEdit = false
    var body: some View {
        TextField("Enter text", text: $text)
            .frame(width: textSize.width, height: textSize.height)
            .font(.title)
            .foregroundStyle(Color.blue)
            .border(isEdit ? .clear : Color.blue.opacity(0.6), width: 3.0)
            .multilineTextAlignment(.center)
            .onChange(of: text) { newValue in
                if isEdit == true {
                    isEdit = false
                }
                if !newValue.isEmpty {
                    textSize = text.SizeOfString(ofFont: .preferredFont(forTextStyle: .title1))
                }
            }
            .onSubmit {
                if !text.isEmpty {
                    textSize = text.SizeOfString(ofFont: .preferredFont(forTextStyle: .title1))
                    isEdit = true
                }
            }
        
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        dragOffset = gesture.translation
                    }
                    .onEnded { gesture in
                        dragOffset = gesture.translation
                        textLocation = gesture.location
                    }
            )
    }
}

extension String {
    func SizeOfString(ofFont: UIFont) -> CGSize {
        let fontAttribute = [NSAttributedString.Key.font: ofFont]
        let text = self + " " // add 1 distance
        return text.size(withAttributes: fontAttribute)
    }
}

