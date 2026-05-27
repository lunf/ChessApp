//
//  ChessKit+AppMapping.swift
//  ChessApp
//

import ChessKit

extension Square {
    init(_ square: ChessKit.Square) {
        self.init(file: square.rawValue % 8, rank: square.rawValue / 8)
    }

    var chessKitSquare: ChessKit.Square {
        ChessKit.Square(rawValue: rank * 8 + file) ?? .a1
    }
}

extension Piece {
    init(_ piece: ChessKit.Piece) {
        self.init(type: PieceType(piece.kind), color: PieceColor(piece.color))
    }
}

extension PieceColor {
    init(_ color: ChessKit.Piece.Color) {
        self = color == .white ? .white : .black
    }
}

extension PieceType {
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

extension ChessKit.Piece.Kind {
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

extension ChessKit.Position {
    var appBoard: [Square: Piece] {
        Dictionary(
            uniqueKeysWithValues: pieces.map {
                (Square($0.square), Piece($0))
            }
        )
    }
}
