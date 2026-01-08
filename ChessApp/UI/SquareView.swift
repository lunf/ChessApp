//
//  SquareView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 20/12/25.
//
import SwiftUI

struct SquareView: View {

    let piece: Piece?
    let square: Square
    let isSelected: Bool
    let isLegalTarget: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.squareColor(file: square.file, rank: square.rank))
                .overlay(
                    isSelected
                        ? Color.selectedSquare
                        : isLegalTarget
                            ? Color.legalSquare
                            : Color.squareColor(file: square.file, rank: square.rank)
                )

            if let piece {
                Image(piece.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
        .frame(width: 44, height: 44)
    }
}
