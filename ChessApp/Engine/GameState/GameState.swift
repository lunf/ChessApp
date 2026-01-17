//
//  GameState.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 18/12/25.
//

import Combine
import Foundation

@MainActor
final class GameState: ObservableObject {

    @Published var board: [Square: Piece] = [:]
    @Published var selectedSquare: Square?
    @Published var legalMoves: Set<Square> = []
    @Published private(set) var moveHistory: [String] = []

    var sideToMove: PieceColor = .white
    var castlingRights = CastlingRights()

    init() {
        reset()
    }

    func reset() {
        board = Self.startPosition()
        sideToMove = .white
        castlingRights = CastlingRights()
        clearSelection()
    }
    
    func load(fromFEN fen: String) {
        print("Loading FEN: \(fen)")
        reset()
        applyFEN(fen)
    }
    
    func recordMove(_ uci: String) {
        moveHistory.append(uci)
    }
    
    func setMoveHistory(_ moves: [String]) {
        moveHistory = moves
    }
    
    func clearSelection() {
        selectedSquare = nil
        legalMoves.removeAll()
    }

    func piece(at square: Square) -> Piece? {
        board[square]
    }

    func move(from: Square, to: Square) {
        guard let piece = board[from] else { return }

        // King Castling
        if isKingCastling(from: from, to: to, piece: piece) {
            performCastling(from: from, to: to, piece: piece)
            sideToMove = sideToMove.opposite
            return
        }

        // Pawn promotion check
        if piece.type == .pawn && isPromotionSquare(piece: piece, to: to) {
            // Defer promotion choice to UI
            board[from] = nil
            board[to] = piece
            return
        }

        // ───── Normal move ─────
        board[to] = piece
        board[from] = nil
        sideToMove = sideToMove.opposite

        updateCastlingRights(piece: piece, from: from)
    }

    func applyUCIMove(_ uciMove: String) {
        guard uciMove.count >= 4 else { return }

        let chars = Array(uciMove)
        let fromSquare = Square(
            file: Int(chars[0].asciiValue! - 97),
            rank: Int(chars[1].asciiValue! - 49)
        )
        let toSquare = Square(
            file: Int(chars[2].asciiValue! - 97),
            rank: Int(chars[3].asciiValue! - 49)
        )

        move(from: fromSquare, to: toSquare)
    }

    func gameResult() -> GameResult {
        let side = sideToMove

        let inCheck = isKingInCheck(color: side)
        let hasMoves = hasAnyLegalMove(for: side)

        if !hasMoves {
            if inCheck {
                return .checkmate(winner: side.opposite)
            } else {
                return .stalemate
            }
        }

        if inCheck {
            return .check(color: side)
        }

        return .ongoing
    }

    // MARK: Helper
    private static func startPosition() -> [Square: Piece] {
        var b: [Square: Piece] = [:]

        // Pawns
        for f in 0..<8 {
            b[Square(file: f, rank: 1)] = Piece(type: .pawn, color: .white)
            b[Square(file: f, rank: 6)] = Piece(type: .pawn, color: .black)
        }

        let backRank: [PieceType] =
            [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]

        for (f, t) in backRank.enumerated() {
            b[Square(file: f, rank: 0)] = Piece(type: t, color: .white)
            b[Square(file: f, rank: 7)] = Piece(type: t, color: .black)
        }

        return b
    }
}
