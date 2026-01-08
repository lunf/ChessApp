//
//  PromotionSheet.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 25/12/25.
//
import SwiftUI

struct PromotionSheet: View {
    let color: PieceColor
    let onSelect: (PieceType) -> Void

    private let options: [PieceType] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        VStack(spacing: 20) {
            Text("Promote Pawn")
                .font(.title.bold())

            HStack(spacing: 24) {
                ForEach(options, id: \.self) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        Text(Piece(type: type, color: color).symbol)
                            .font(.system(size: 48))
                            .frame(width: 64, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }
            }
        }
        .padding(32)
        .presentationDetents([.height(220)])
        .interactiveDismissDisabled() // must choose
    }
}
