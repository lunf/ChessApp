//
//  MessageBuble.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 29/12/25.
//

import SwiftUI

struct MessageBubble: View {

    let message: MentorMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .ai {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.blue)
            }

            Text(message.text)
                .font(.body)
                .padding(12)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case .ai:
            return Color.blue.opacity(0.12)
        case .user:
            return Color.green.opacity(0.12)
        case .system:
            return Color.gray.opacity(0.12)
        }
    }
}

