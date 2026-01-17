//
//  GameState+Promotion.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 17/1/26.
//

//  GameState+Promotion.swift
//  ChessApp

import Foundation

extension GameState {

    // MARK: - Promotion (Engine)

    /// Engine promotion: pawn has NOT been moved yet
    func promotePawn(from: Square, to: Square, promoteTo newType: PieceType) {
        applyPromotion(pawnFrom: from, pawnAt: to, promoteTo: newType)
    }

    // MARK: - Promotion (Human)

    /// Human promotion: pawn already moved, only replace piece
    func promotePawn(at square: Square, promoteTo newType: PieceType) {
        applyPromotion(pawnFrom: nil, pawnAt: square, promoteTo: newType)
    }
    
    // MARK: - Promotion helpers

    func isPromotionSquare(piece: Piece, to square: Square) -> Bool {
        piece.color == .white ? square.rank == 7 : square.rank == 0
    }

    // MARK: - Internal

    fileprivate func applyPromotion(pawnFrom from: Square?,pawnAt to: Square, promoteTo newType: PieceType) {
        guard newType != .pawn && newType != .king else {
            assertionFailure("Invalid promotion type")
            return
        }

        let pawnSquare = from ?? to

        guard let pawn = board[pawnSquare], pawn.type == .pawn else {
            assertionFailure("No pawn to promote")
            return
        }

        if let from {
            board[from] = nil
        }

        board[to] = Piece(type: newType, color: pawn.color)

        sideToMove = sideToMove.opposite
        clearSelection()
    }
}
