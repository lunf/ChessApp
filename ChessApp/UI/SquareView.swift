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
    let showsRank: Bool
    let showsFile: Bool

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

            if showsRank {
                Text("\(square.rank + 1)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(coordinateColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(3)
            }

            if showsFile {
                Text(square.fileLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(coordinateColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(3)
            }
        }
        .frame(width: 44, height: 44)
    }

    private var coordinateColor: Color {
        (square.file + square.rank) % 2 == 0
            ? Color(red: 0.55, green: 0.40, blue: 0.25)
            : Color(red: 0.93, green: 0.89, blue: 0.85)
    }
}
