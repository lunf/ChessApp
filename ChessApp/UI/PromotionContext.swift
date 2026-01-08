//
//  PromotionContext.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 26/12/25.
//

import Foundation

struct PromotionContext: Identifiable {
    let id = UUID()
    let from: Square
    let to: Square
    let color: PieceColor
}
