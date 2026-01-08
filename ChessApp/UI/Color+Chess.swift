//
//  Color+Chess.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 20/12/25.
//

import SwiftUI

extension Color {

    static func squareColor(file: Int, rank: Int) -> Color {
        // Light square when (file + rank) is even
        (file + rank) % 2 == 0
            ? Color(red: 0.93, green: 0.89, blue: 0.85)
            : Color(red: 0.55, green: 0.40, blue: 0.25)
    }

    static let selectedSquare = Color.yellow.opacity(0.6)

    static let legalSquare = Color.green.opacity(0.4)
}
