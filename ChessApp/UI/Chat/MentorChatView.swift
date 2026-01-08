//
//  MentorChatView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 29/12/25.
//

import SwiftUI

struct MentorChatView: View {

    let messages: [MentorMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
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

