//
//  MentorChatView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 29/12/25.
//

import SwiftUI

struct MentorChatView: View {

    let messages: [MentorMessage]
    let isThinking: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if isThinking {
                        MentorThinkingBubble()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(.ultraThinMaterial)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: messages) {
                guard messages.last != nil else { return }
                scrollToBottom(proxy)
            }
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct MentorThinkingBubble: View {
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.blue)

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Thinking...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
