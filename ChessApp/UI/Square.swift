//
//  SquareView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 20/12/25.
//

struct Square: Hashable, Identifiable {

    let file: Int   // 0 = a, 7 = h
    let rank: Int   // 0 = rank 1, 7 = rank 8

    var id: String { uci }

    var uci: String {
        let fileChar = Character(UnicodeScalar(97 + file)!)
        let rankChar = Character(UnicodeScalar(49 + rank)!)
        return "\(fileChar)\(rankChar)"
    }
    
    var notation: String {
        let fileChar = Character(UnicodeScalar(97 + file)!)
        return "\(fileChar)\(rank + 1)"
    }

    var fileLabel: String {
        String(Character(UnicodeScalar(97 + file)!))
    }
}
