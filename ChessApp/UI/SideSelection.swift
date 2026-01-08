//
//  SideSelection.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 25/12/25.
//

enum SideSelection: String, CaseIterable, Identifiable {
    case white = "White"
    case black = "Black"
    var id: String { rawValue }
}
