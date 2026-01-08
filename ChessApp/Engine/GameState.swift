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

    var sideToMove: PieceColor = .white
    var castlingRights = CastlingRights()

    var fen: String {
        generateFEN()
    }

    init() {
        reset()
    }

    func reset() {
        board = Self.startPosition()
        sideToMove = .white
        castlingRights = CastlingRights()
        clearSelection()
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

    // For Engine (pawn not moved yet): need move in board and type
    func promotePawn(from: Square, to: Square, promoteTo newType: PieceType) {
        applyPromotion(pawnFrom: from, pawnAt: to, promoteTo: newType)
    }
    
    // For User (pawn already moved): now only update piece type on board
    func promotePawn(at square: Square, promoteTo newType: PieceType) {
        applyPromotion(pawnFrom: nil, pawnAt: square, promoteTo: newType)
    }


    // MARK: Helper
    
    private func applyPromotion(pawnFrom from: Square?, pawnAt to: Square, promoteTo newType: PieceType) {
        guard newType != .pawn && newType != .king else {
            assertionFailure("Invalid promotion type")
            return
        }

        let pawnSquare = from ?? to

        guard let pawn = board[pawnSquare], pawn.type == .pawn else {
            assertionFailure("No pawn to promote")
            return
        }

        // Remove pawn if needed
        if let from {
            board[from] = nil
        }

        // Place promoted piece
        board[to] = Piece(type: newType, color: pawn.color)

        sideToMove = sideToMove.opposite
        selectedSquare = nil
        legalMoves.removeAll()
    }

    private func isPromotionSquare(piece: Piece, to square: Square) -> Bool {
        piece.color == .white ? square.rank == 7 : square.rank == 0
    }

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

    private func isKingCastling(from: Square, to: Square, piece: Piece) -> Bool
    {
        piece.type == .king && abs(from.file - to.file) == 2
    }

    private func performCastling(from: Square, to: Square, piece: Piece) {
        let rank = from.rank

        // Move king
        board[from] = nil
        board[to] = piece

        if to.file == 6 {
            // ───── King-side ─────
            let rookFrom = Square(file: 7, rank: rank)
            let rookTo = Square(file: 5, rank: rank)

            board[rookTo] = board[rookFrom]
            board[rookFrom] = nil
        } else if to.file == 2 {
            // ───── Queen-side ─────
            let rookFrom = Square(file: 0, rank: rank)
            let rookTo = Square(file: 3, rank: rank)

            board[rookTo] = board[rookFrom]
            board[rookFrom] = nil
        }

        // Clear castling rights
        if piece.color == .white {
            castlingRights.whiteKingSide = false
            castlingRights.whiteQueenSide = false
        } else {
            castlingRights.blackKingSide = false
            castlingRights.blackQueenSide = false
        }

        if piece.type == .rook {
            if from == Square(file: 0, rank: 0) {
                castlingRights.whiteQueenSide = false
            }
            if from == Square(file: 7, rank: 0) {
                castlingRights.whiteKingSide = false
            }
            if from == Square(file: 0, rank: 7) {
                castlingRights.blackQueenSide = false
            }
            if from == Square(file: 7, rank: 7) {
                castlingRights.blackKingSide = false
            }
        }

    }

    private func updateCastlingRights(piece: Piece, from: Square) {
        guard piece.type == .rook || piece.type == .king else { return }

        switch (piece.color, from) {
        case (.white, Square(file: 0, rank: 0)):
            castlingRights.whiteQueenSide = false
        case (.white, Square(file: 7, rank: 0)):
            castlingRights.whiteKingSide = false
        case (.black, Square(file: 0, rank: 7)):
            castlingRights.blackQueenSide = false
        case (.black, Square(file: 7, rank: 7)):
            castlingRights.blackKingSide = false
        default:
            break
        }

        if piece.type == .king {
            if piece.color == .white {
                castlingRights.whiteKingSide = false
                castlingRights.whiteQueenSide = false
            } else {
                castlingRights.blackKingSide = false
                castlingRights.blackQueenSide = false
            }
        }
    }

    private func generateFEN() -> String {
        // Piece placement
        var ranks: [String] = []

        for rank in stride(from: 7, through: 0, by: -1) {
            var empty = 0
            var line = ""

            for file in 0..<8 {
                let sq = Square(file: file, rank: rank)

                if let piece = board[sq] {
                    if empty > 0 {
                        line += "\(empty)"
                        empty = 0
                    }
                    line += piece.fenSymbol
                } else {
                    empty += 1
                }
            }

            if empty > 0 {
                line += "\(empty)"
            }

            ranks.append(line)
        }

        let placement = ranks.joined(separator: "/")

        // Side to move
        let side = sideToMove == .white ? "w" : "b"

        // Castling rights
        let castling = castlingRights.fenString

        // En passant (not implemented yet)
        let enPassant = "-"

        // Move counters
        let halfmove = "0"
        let fullmove = "1"

        return
            "\(placement) \(side) \(castling) \(enPassant) \(halfmove) \(fullmove)"
    }

}
