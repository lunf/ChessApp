//
//  CastlingRights.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 21/12/25.
//

struct CastlingRights {
    var whiteKingSide = true
    var whiteQueenSide = true
    var blackKingSide = true
    var blackQueenSide = true
    
    var fenString: String {
        var s = ""
        if whiteKingSide { s += "K" }
        if whiteQueenSide { s += "Q" }
        if blackKingSide { s += "k" }
        if blackQueenSide { s += "q" }
        return s.isEmpty ? "-" : s
    }
}
