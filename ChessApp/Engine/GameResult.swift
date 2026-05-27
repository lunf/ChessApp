//
//  GameResult.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 23/12/25.
//

enum GameResult: Equatable {
    case ongoing
    case check(color: PieceColor)
    case checkmate(winner: PieceColor)
    case stalemate
    case draw(reason: String)

    var isTerminal: Bool {
        switch self {
        case .checkmate, .stalemate, .draw:
            return true
        default:
            return false
        }
    }

    var overlayText: String {
        switch self {
        case .check(let color):
            return color == .white ? "White is in Check" : "Black is in Check"
        case .checkmate(let winner):
            return winner == .white
                ? "Checkmate — White wins" : "Checkmate — Black wins"
        case .stalemate:
            return "Stalemate"
        case .draw(let reason):
            return "Draw — \(reason)"
        case .ongoing:
            return ""
        }
    }

    var isTransient: Bool {
        if case .check = self { return true }
        return false
    }
}
