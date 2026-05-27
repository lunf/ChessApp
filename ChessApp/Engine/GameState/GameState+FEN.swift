//
//  GameState+FEN.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 17/1/26.
//

//
//  GameState+FEN.swift
//  ChessApp
//

extension GameState {

    // MARK: - Public API

    /// Current position as FEN (engine-safe)
    var fen: String {
        generateFEN()
    }

    /// Load a full position from FEN
    func applyFEN(_ fen: String) {
        let parts = fen.split(separator: " ")
        guard parts.count >= 4 else {
            assertionFailure("Invalid FEN")
            return
        }

        applyPiecePlacement(String(parts[0]))
        applySideToMove(String(parts[1]))
        applyCastlingRights(String(parts[2]))
        applyEnPassantTarget(String(parts[3]))

        // Clocks intentionally ignored
        clearSelection()
    }

    // MARK: - FEN Generation

    private func generateFEN() -> String {
        let placement = generatePiecePlacement()
        let side = sideToMove == .white ? "w" : "b"
        let castling = sanitizedCastlingString()
        let enPassant = enPassantTarget?.uci ?? "-"
        let halfmove = "0"
        let fullmove = "1"

        return "\(placement) \(side) \(castling) \(enPassant) \(halfmove) \(fullmove)"
    }

    private func generatePiecePlacement() -> String {
        var ranks: [String] = []

        for rank in stride(from: 7, through: 0, by: -1) {
            var empty = 0
            var line = ""

            for file in 0..<8 {
                let square = Square(file: file, rank: rank)

                if let piece = board[square] {
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

        return ranks.joined(separator: "/")
    }

    // MARK: - FEN Parsing

    private func applyPiecePlacement(_ placement: String) {
        board.removeAll()

        let ranks = placement.split(separator: "/")
        guard ranks.count == 8 else {
            assertionFailure("Invalid FEN ranks")
            return
        }

        for (rankIndex, rankString) in ranks.enumerated() {
            var file = 0
            let rank = 7 - rankIndex

            for char in rankString {
                if let empty = char.wholeNumberValue {
                    file += empty
                } else {
                    guard
                        let piece = Piece(fenChar: char)
                    else {
                        assertionFailure("Invalid FEN piece: \(char)")
                        return
                    }

                    let square = Square(file: file, rank: rank)
                    board[square] = piece
                    file += 1
                }
            }
        }
    }

    private func applySideToMove(_ value: String) {
        if value == "w" {
            sideToMove = .white
        } else if value == "b" {
            sideToMove = .black
        } else {
            sideToMove = .white // safe default
            assertionFailure("Invalid side to move in FEN: \(value)")
        }
    }

    private func applyCastlingRights(_ value: String) {
        castlingRights = CastlingRights()

        guard value != "-" else { return }

        castlingRights.whiteKingSide  = value.contains("K")
        castlingRights.whiteQueenSide = value.contains("Q")
        castlingRights.blackKingSide  = value.contains("k")
        castlingRights.blackQueenSide = value.contains("q")
    }

    private func applyEnPassantTarget(_ value: String) {
        guard value != "-" else {
            enPassantTarget = nil
            return
        }

        let chars = Array(value)
        guard chars.count == 2,
              let fileAscii = chars[0].asciiValue,
              let rank = Int(String(chars[1]))
        else {
            enPassantTarget = nil
            assertionFailure("Invalid en passant square in FEN: \(value)")
            return
        }

        let square = Square(file: Int(fileAscii - 97), rank: rank - 1)
        enPassantTarget = (0..<8).contains(square.file) && (0..<8).contains(square.rank) ? square : nil
    }
    
    private func sanitizedCastlingString() -> String {
        var result = ""

        // White
        if board[Square(file: 4, rank: 0)] == Piece(type: .king, color: .white) {
            if castlingRights.whiteKingSide,
               board[Square(file: 7, rank: 0)] == Piece(type: .rook, color: .white) {
                result += "K"
            }
            if castlingRights.whiteQueenSide,
               board[Square(file: 0, rank: 0)] == Piece(type: .rook, color: .white) {
                result += "Q"
            }
        }

        // Black
        if board[Square(file: 4, rank: 7)] == Piece(type: .king, color: .black) {
            if castlingRights.blackKingSide,
               board[Square(file: 7, rank: 7)] == Piece(type: .rook, color: .black) {
                result += "k"
            }
            if castlingRights.blackQueenSide,
               board[Square(file: 0, rank: 7)] == Piece(type: .rook, color: .black) {
                result += "q"
            }
        }

        return result.isEmpty ? "-" : result
    }
}
