//
//  UCIMove.swift
//  ChessApp
//

struct UCIMove: Equatable, Hashable {
    let from: Square
    let to: Square
    let promotion: PieceType?

    init(from: Square, to: Square, promotion: PieceType? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    init?(_ rawValue: String) {
        guard rawValue.count >= 4 else { return nil }

        let chars = Array(rawValue)
        guard
            let from = Square(file: chars[0], rank: chars[1]),
            let to = Square(file: chars[2], rank: chars[3])
        else {
            return nil
        }

        self.from = from
        self.to = to
        self.promotion = chars.count >= 5 ? PieceType(uciChar: chars[4]) : nil
    }

    var rawValue: String {
        from.uci + to.uci + (promotion?.uciChar ?? "")
    }
}

private extension Square {
    init?(file: Character, rank: Character) {
        guard let fileAscii = file.asciiValue,
              (97...104).contains(fileAscii),
              let rankValue = Int(String(rank)),
              (1...8).contains(rankValue)
        else {
            return nil
        }

        self.init(file: Int(fileAscii - 97), rank: rankValue - 1)
    }
}
