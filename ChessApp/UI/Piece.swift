//
//  Piece.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 20/12/25.
//
enum PieceType {
    case king, queen, rook, bishop, knight, pawn
    
    // UCI promotion character (lowercase)
    var uciChar: String? {
        switch self {
            case .queen:  return "q"
            case .rook:   return "r"
            case .bishop: return "b"
            case .knight: return "n"
            default:      return nil
        }
    }
    // Only for promotion
    init?(uciChar: Character) {
        switch uciChar {
            case "q": self = .queen
            case "r": self = .rook
            case "b": self = .bishop
            case "n": self = .knight
            default: return nil
        }
    }
}

enum PieceColor {
    case white, black
    
    var opposite: PieceColor {
        self == .white ? .black : .white
    }
    
    var text: String {
        self == .white ? "white" : "black"
    }
}

struct Piece {

    let type: PieceType
    let color: PieceColor

    var symbol: String {
        switch (type, color) {
        case (.king, .white):   return "♔"
        case (.queen, .white): return "♕"
        case (.rook, .white):  return "♖"
        case (.bishop, .white):return "♗"
        case (.knight, .white):return "♘"
        case (.pawn, .white):  return "♙"
        case (.king, .black):   return "♚"
        case (.queen, .black): return "♛"
        case (.rook, .black):  return "♜"
        case (.bishop, .black):return "♝"
        case (.knight, .black):return "♞"
        case (.pawn, .black):  return "♟"
        }
    }
    
    var fenSymbol: String {
        let s: String
        switch type {
        case .pawn:   s = "p"
        case .knight: s = "n"
        case .bishop: s = "b"
        case .rook:   s = "r"
        case .queen:  s = "q"
        case .king:   s = "k"
        }
        return color == .white ? s.uppercased() : s
    }
}
