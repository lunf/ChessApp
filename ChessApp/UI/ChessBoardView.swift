//
//  ChessBoardView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 18/12/25.
//

import SwiftUI

struct ChessBoardView: View {

    @ObservedObject var game: GameState
    let showLegalMoves: Bool
    let flipped: Bool
    let onMove: (String) -> Void

//    @State private var selected: Square?
//    @State private var legalTargets: Set<Square> = []

    private let ranks = Array((0...7).reversed())  // 7 -> 0
    private let files = Array(0...7)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ranks, id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(files, id: \.self) { file in
                        let visualSquare = Square(file: file, rank: rank)
                        let logicalSquare = mapSquare(visualSquare)

                        SquareView(
                            piece: game.piece(at: logicalSquare),
                            square: logicalSquare,
                            isSelected: logicalSquare == game.selectedSquare,
                            isLegalTarget: showLegalMoves
                                && game.legalMoves.contains(logicalSquare),
                            showsRank: visualSquare.file == 0,
                            showsFile: visualSquare.rank == 0
                        )
                        .onTapGesture {
                            handleTap(logicalSquare)
                        }
                    }
                }
            }
        }
        .onChange(of: flipped) { _, _ in
            game.clearSelection()
        }
    }

    // MARK: - Board orientation

    private var rankRange: [Int] {
        flipped ? Array(0..<8) : Array((0..<8).reversed())
    }

    private var fileRange: [Int] {
        flipped ? Array((0..<8).reversed()) : Array(0..<8)
    }

    // map the tapped square back to the real square when the board is flipped.
    func mapSquare(_ visual: Square) -> Square {
        flipped
            ? Square(file: 7 - visual.file, rank: 7 - visual.rank)
            : visual
    }

    private func handleTap(_ square: Square) {
        // First tap → select piece
        if game.selectedSquare == nil {
            guard let piece = game.piece(at: square),
                piece.color == game.sideToMove
            else { return }

            game.selectedSquare = square
            game.legalMoves =
                showLegalMoves
                ? game.legalMoves(from: square)
                : []
            return
        }

        // Tap same square → deselect
        if square == game.selectedSquare {
            game.clearSelection()
            return
        }

        // Second tap → attempt move
        let from = game.selectedSquare!
        let to = square

        // ───── Valid move ─────
        if !showLegalMoves || game.legalMoves.contains(to) {
            if game.isLegalMove(from: from, to: to) {
                game.move(from: from, to: to)
                onMove(from.uci + to.uci)
            }
            game.clearSelection()
            return
        }

        // ───── Tap another own piece → reselect ─────
        if let piece = game.piece(at: square),
            piece.color == game.sideToMove
        {

            game.selectedSquare = square
            game.legalMoves = showLegalMoves ? game.legalMoves(from: square) : []
            return
        }

        // ───── Invalid tap → clear ─────
        game.clearSelection()
    }

    private func toUci(from: Square, to: Square) -> String {
        func fileChar(_ f: Int) -> String {
            String(UnicodeScalar(97 + f)!)
        }
        return
            "\(fileChar(from.file))\(from.rank+1)\(fileChar(to.file))\(to.rank+1)"
    }
}
