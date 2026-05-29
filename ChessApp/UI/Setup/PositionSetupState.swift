//
//  PositionSetupState.swift
//  ChessApp
//

import ChessKit
import Combine
import Foundation

@MainActor
final class PositionSetupState: ObservableObject {
    private static let startingFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    enum Tool: Hashable {
        case piece(Piece)
        case erase
        case move
    }

    @Published var board: [Square: Piece] = [:]
    @Published var selectedTool: Tool = .move
    @Published var selectedSquare: Square?
    @Published var sideToMove: PieceColor = .white
    @Published var whiteCanCastleKingSide = true
    @Published var whiteCanCastleQueenSide = true
    @Published var blackCanCastleKingSide = true
    @Published var blackCanCastleQueenSide = true
    @Published var fenText = ""
    @Published var validationMessage: String?

    init(initialFEN: String) {
        loadFEN(initialFEN)
    }

    var currentFEN: String {
        buildFEN()
    }

    func handleTap(_ square: Square) {
        validationMessage = nil

        switch selectedTool {
        case .piece(let piece):
            board[square] = piece
            fenText = buildFEN()
        case .erase:
            board.removeValue(forKey: square)
            fenText = buildFEN()
        case .move:
            handleMoveTap(square)
        }
    }

    func clearBoard() {
        board.removeAll()
        selectedSquare = nil
        fenText = buildFEN()
    }

    func resetToStartingPosition() {
        loadFEN(Self.startingFEN)
    }

    func importFEN() -> Bool {
        loadFEN(fenText)
    }

    func validatedFEN() -> String? {
        let fen = buildFEN()
        guard ChessKit.Position(fen: fen) != nil else {
            validationMessage = "Position is not valid. Check kings, pawns, and FEN fields."
            return nil
        }

        validationMessage = nil
        fenText = fen
        return fen
    }

    func refreshFEN() {
        fenText = buildFEN()
    }

    private func handleMoveTap(_ square: Square) {
        if let selectedSquare {
            if selectedSquare == square {
                self.selectedSquare = nil
                return
            }

            if let piece = board[selectedSquare] {
                board.removeValue(forKey: selectedSquare)
                board[square] = piece
                fenText = buildFEN()
            }

            self.selectedSquare = nil
            return
        }

        if board[square] != nil {
            selectedSquare = square
        }
    }

    @discardableResult
    private func loadFEN(_ fen: String) -> Bool {
        guard let position = ChessKit.Position(fen: fen.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            validationMessage = "Invalid FEN."
            return false
        }

        board = position.appBoard
        sideToMove = PieceColor(position.sideToMove)
        selectedSquare = nil
        selectedTool = .move
        applyFENMetadata(fen)
        fenText = position.fen
        validationMessage = nil
        return true
    }

    private func applyFENMetadata(_ fen: String) {
        let fields = fen.split(separator: " ").map(String.init)
        guard fields.count >= 3 else {
            setCastlingRights(from: "-")
            return
        }

        setCastlingRights(from: fields[2])
    }

    private func setCastlingRights(from field: String) {
        whiteCanCastleKingSide = field.contains("K")
        whiteCanCastleQueenSide = field.contains("Q")
        blackCanCastleKingSide = field.contains("k")
        blackCanCastleQueenSide = field.contains("q")
    }

    private func buildFEN() -> String {
        let placement = boardPlacementFEN()
        let side = sideToMove == .white ? "w" : "b"
        let castling = castlingFEN()
        return "\(placement) \(side) \(castling) - 0 1"
    }

    private func boardPlacementFEN() -> String {
        var ranks: [String] = []

        for rank in stride(from: 7, through: 0, by: -1) {
            var emptyCount = 0
            var rankText = ""

            for file in 0...7 {
                let square = Square(file: file, rank: rank)
                if let piece = board[square] {
                    if emptyCount > 0 {
                        rankText += String(emptyCount)
                        emptyCount = 0
                    }
                    rankText += piece.fenSymbol
                } else {
                    emptyCount += 1
                }
            }

            if emptyCount > 0 {
                rankText += String(emptyCount)
            }

            ranks.append(rankText)
        }

        return ranks.joined(separator: "/")
    }

    private func castlingFEN() -> String {
        var rights = ""
        if whiteCanCastleKingSide { rights += "K" }
        if whiteCanCastleQueenSide { rights += "Q" }
        if blackCanCastleKingSide { rights += "k" }
        if blackCanCastleQueenSide { rights += "q" }
        return rights.isEmpty ? "-" : rights
    }
}
