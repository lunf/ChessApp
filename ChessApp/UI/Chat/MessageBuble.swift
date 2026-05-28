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

            MarkdownMessageText(text: message.text)
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

private struct MarkdownMessageText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(block.enumerated()), id: \.offset) { _, line in
                        markdownText(line)
                    }
                }
            }
        }
        .font(.body)
        .multilineTextAlignment(.leading)
    }

    private var blocks: [[String]] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { block in
                block
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map(String.init)
            }
            .filter { !$0.isEmpty }
    }

    private func markdownText(_ line: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        if let markdown = try? AttributedString(markdown: line, options: options) {
            return Text(markdown)
        }

        return Text(line)
    }
}
