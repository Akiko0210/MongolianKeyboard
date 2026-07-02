//
//  VerticalMongolianText.swift
//  MongolKey
//
//  SwiftUI wrapper around the shared Core Text `VerticalMongolianView` so the
//  app can drop correctly-rendered vertical Mongolian into any SwiftUI layout.
//

import SwiftUI

struct VerticalMongolianText: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 40
    var textColor: UIColor = .label

    func makeUIView(context: Context) -> VerticalMongolianView {
        let view = VerticalMongolianView(bundle: .main)
        view.alignment = .center
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: VerticalMongolianView, context: Context) {
        view.fontSize = fontSize
        view.textColor = textColor
        view.text = text
    }
}
