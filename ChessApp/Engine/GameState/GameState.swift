//
//  GameState.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 18/12/25.
//

import ChessKit
import Combine
import Foundation

@MainActor
final class GameState: ObservableObject {

    @Published private(set) var board: [Square: Piece] = [:]
    @Published var selectedSquare: Square?
    @Published var legalMoves: Set<Square> = []
    @Published private(set) var moveHistory: [String] = []
    @Published private(set) var moveNotations: [String] = []

    private var chessBoard = ChessKit.Board()
    private var pendingPromotionMove: ChessKit.Move?
    private(set) var lastMoveNotation: String?

    var sideToMove: PieceColor {
        PieceColor(chessBoard.position.sideToMove)
    }

    var fen: String {
        chessBoard.position.fen
    }

    init() {
        syncBoard()
    }

    func reset() {
        chessBoard = ChessKit.Board()
        pendingPromotionMove = nil
        moveHistory.removeAll()
        moveNotations.removeAll()
        lastMoveNotation = nil
        syncBoard()
        clearSelection()
    }

    @discardableResult
    func load(fromFEN fen: String) -> Bool {
        guard let position = ChessKit.Position(fen: fen) else {
            print("Invalid FEN: \(fen)")
            return false
        }

        chessBoard = ChessKit.Board(position: position)
        pendingPromotionMove = nil
        lastMoveNotation = nil
        syncBoard()
        clearSelection()
        return true
    }

    func recordMove(_ uci: String, notation: String? = nil) {
        moveHistory.append(uci)
        moveNotations.append(notation ?? lastMoveNotation ?? uci)
    }

    func setMoveHistory(_ moves: [String]) {
        moveHistory = moves
    }

    func setMoveNotations(_ notations: [String]) {
        moveNotations = notations
    }

    func clearSelection() {
        selectedSquare = nil
        legalMoves.removeAll()
    }

    func piece(at square: Square) -> Piece? {
        board[square]
    }

    func legalMoves(from square: Square) -> Set<Square> {
        Set(chessBoard.legalMoves(forPieceAt: square.chessKitSquare).map(Square.init))
    }

    func isLegalMove(from: Square, to: Square) -> Bool {
        chessBoard.canMove(pieceAt: from.chessKitSquare, to: to.chessKitSquare)
    }

    @discardableResult
    func move(from: Square, to: Square) -> Bool {
        guard let move = chessBoard.move(pieceAt: from.chessKitSquare, to: to.chessKitSquare) else {
            return false
        }

        if case .promotion(let promotionMove) = chessBoard.state {
            pendingPromotionMove = promotionMove
            lastMoveNotation = nil
        } else {
            pendingPromotionMove = nil
            lastMoveNotation = move.san
        }

        syncBoard()
        return true
    }

    @discardableResult
    func applyUCIMove(_ uciMove: String) -> Bool {
        guard let move = UCIMove(uciMove) else { return false }

        if let promotion = move.promotion {
            return promotePawn(from: move.from, to: move.to, promoteTo: promotion)
        }

        return self.move(from: move.from, to: move.to)
    }

    func gameResult() -> GameResult {
        switch chessBoard.state {
        case .active, .promotion:
            return .ongoing
        case .check(let color):
            return .check(color: PieceColor(color))
        case .checkmate(let color):
            return .checkmate(winner: PieceColor(color.opposite))
        case .draw(let reason):
            if reason == .stalemate {
                return .stalemate
            }
            return .draw(reason: reason.rawValue.capitalized)
        }
    }

    // MARK: - Promotion

    @discardableResult
    func promotePawn(from: Square, to: Square, promoteTo newType: PieceType) -> Bool {
        guard let kind = ChessKit.Piece.Kind(newType) else { return false }
        guard board[from]?.type == .pawn, to.rank == 0 || to.rank == 7 else {
            return false
        }
        guard chessBoard.move(pieceAt: from.chessKitSquare, to: to.chessKitSquare) != nil else {
            return false
        }

        if case .promotion(let move) = chessBoard.state {
            let completedMove = chessBoard.completePromotion(of: move, to: kind)
            lastMoveNotation = completedMove.san
        } else {
            return false
        }

        pendingPromotionMove = nil
        syncBoard()
        clearSelection()
        return true
    }

    @discardableResult
    func promotePawn(at square: Square, promoteTo newType: PieceType) -> Bool {
        guard let pendingPromotionMove,
              pendingPromotionMove.end == square.chessKitSquare,
              let kind = ChessKit.Piece.Kind(newType)
        else {
            return false
        }

        let completedMove = chessBoard.completePromotion(of: pendingPromotionMove, to: kind)
        lastMoveNotation = completedMove.san
        self.pendingPromotionMove = nil
        syncBoard()
        clearSelection()
        return true
    }

    func isPromotionSquare(piece: Piece, to square: Square) -> Bool {
        piece.type == .pawn && (square.rank == 0 || square.rank == 7)
    }

    // MARK: - Helpers

    private func syncBoard() {
        board = chessBoard.position.appBoard
    }

}
