//
//  Piece+Asset.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 21/12/25.
//

extension Piece {
    var assetName: String {
        let colorPrefix = color == .white ? "w" : "b"

        let typeName: String = {
            switch type {
            case .king:   return "king"
            case .queen:  return "queen"
            case .rook:   return "rook"
            case .bishop: return "bishop"
            case .knight: return "knight"
            case .pawn:   return "pawn"
            }
        }()

        return "\(typeName)_\(colorPrefix)"
    }
}
