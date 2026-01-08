//
//  GameOverOverlay.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 23/12/25.
//
import SwiftUI

struct GameOverOverlay: View {
    let result: GameResult

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            Text(result.overlayText)
                .font(.title.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
