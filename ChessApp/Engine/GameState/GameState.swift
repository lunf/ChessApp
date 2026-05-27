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

    private var chessBoard = ChessKit.Board()
    private var pendingPromotionMove: ChessKit.Move?

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
        syncBoard()
        clearSelection()
    }

    func load(fromFEN fen: String) {
        guard let position = ChessKit.Position(fen: fen) else {
            assertionFailure("Invalid FEN: \(fen)")
            return
        }

        chessBoard = ChessKit.Board(position: position)
        pendingPromotionMove = nil
        syncBoard()
        clearSelection()
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

    func legalMoves(from square: Square) -> Set<Square> {
        Set(chessBoard.legalMoves(forPieceAt: square.chessKitSquare).map(Square.init))
    }

    func isLegalMove(from: Square, to: Square) -> Bool {
        chessBoard.canMove(pieceAt: from.chessKitSquare, to: to.chessKitSquare)
    }

    func move(from: Square, to: Square) {
        guard chessBoard.move(pieceAt: from.chessKitSquare, to: to.chessKitSquare) != nil else {
            return
        }

        if case .promotion(let promotionMove) = chessBoard.state {
            pendingPromotionMove = promotionMove
        } else {
            pendingPromotionMove = nil
        }

        syncBoard()
    }

    func applyUCIMove(_ uciMove: String) {
        guard let move = UCIMove(uciMove) else { return }

        if let promotion = move.promotion {
            promotePawn(from: move.from, to: move.to, promoteTo: promotion)
        } else {
            self.move(from: move.from, to: move.to)
        }
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

    func promotePawn(from: Square, to: Square, promoteTo newType: PieceType) {
        guard let kind = ChessKit.Piece.Kind(newType) else { return }
        guard chessBoard.move(pieceAt: from.chessKitSquare, to: to.chessKitSquare) != nil else {
            return
        }

        if case .promotion(let move) = chessBoard.state {
            chessBoard.completePromotion(of: move, to: kind)
        }

        pendingPromotionMove = nil
        syncBoard()
        clearSelection()
    }

    func promotePawn(at square: Square, promoteTo newType: PieceType) {
        guard let pendingPromotionMove,
              pendingPromotionMove.end == square.chessKitSquare,
              let kind = ChessKit.Piece.Kind(newType)
        else {
            return
        }

        chessBoard.completePromotion(of: pendingPromotionMove, to: kind)
        self.pendingPromotionMove = nil
        syncBoard()
        clearSelection()
    }

    func isPromotionSquare(piece: Piece, to square: Square) -> Bool {
        piece.type == .pawn && (square.rank == 0 || square.rank == 7)
    }

    // MARK: - Helpers

    private func syncBoard() {
        board = Dictionary(
            uniqueKeysWithValues: chessBoard.position.pieces.map {
                (Square($0.square), Piece($0))
            }
        )
    }

}

private extension Square {
    init(_ square: ChessKit.Square) {
        self.init(file: square.rawValue % 8, rank: square.rawValue / 8)
    }

    var chessKitSquare: ChessKit.Square {
        ChessKit.Square(rawValue: rank * 8 + file) ?? .a1
    }
}

private extension Piece {
    init(_ piece: ChessKit.Piece) {
        self.init(type: PieceType(piece.kind), color: PieceColor(piece.color))
    }
}

private extension PieceColor {
    init(_ color: ChessKit.Piece.Color) {
        self = color == .white ? .white : .black
    }
}

private extension PieceType {
    init(_ kind: ChessKit.Piece.Kind) {
        switch kind {
        case .king:
            self = .king
        case .queen:
            self = .queen
        case .rook:
            self = .rook
        case .bishop:
            self = .bishop
        case .knight:
            self = .knight
        case .pawn:
            self = .pawn
        }
    }
}

private extension ChessKit.Piece.Kind {
    init?(_ pieceType: PieceType) {
        switch pieceType {
        case .queen:
            self = .queen
        case .rook:
            self = .rook
        case .bishop:
            self = .bishop
        case .knight:
            self = .knight
        case .king, .pawn:
            return nil
        }
    }
}
