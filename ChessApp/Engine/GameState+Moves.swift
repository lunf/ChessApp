//
//  GameState+Moves.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 20/12/25.
//

extension GameState {

    // MARK: - Public API
    func legalMoves(from square: Square) -> Set<Square> {
        guard let piece = board[square] else { return [] }

        var pseudo = pseudoMoves(from: square, piece: piece)

        if piece.type == .king {
            addCastlingMoves(from: square, piece: piece, into: &pseudo)
        }

        // Filter moves that leave king in check
        return pseudo.filter { move in
            !wouldLeaveKingInCheck(from: square, to: move)
        }
    }

    // Filter legal moves (this prevents illegal king moves)
    func pseudoMoves(from: Square, piece: Piece) -> Set<Square> {
        switch piece.type {
        case .pawn: return pawnMoves(from: from, piece)
        case .knight: return knightMoves(from: from, piece)
        case .bishop: return slidingMoves(from, piece, directions: bishopDirs)
        case .rook: return slidingMoves(from, piece, directions: rookDirs)
        case .queen:
            return slidingMoves(from, piece, directions: bishopDirs + rookDirs)
        case .king: return kingMoves(from: from, piece)
        }
    }

    func isLegalMove(from: Square, to: Square) -> Bool {
        return legalMoves(from: from).contains(to)
    }

    func isCheckmate(for color: PieceColor) -> Bool {
        guard isKingInCheck(color: color) else { return false }

        return !hasAnyLegalMove(for: color)
    }

    // Stalemate = king is NOT in check and no legal moves exist

    func isStalemate(for color: PieceColor) -> Bool {
        guard !isKingInCheck(color: color) else { return false }

        return !hasAnyLegalMove(for: color)
    }

    func isKingInCheck(color: PieceColor) -> Bool {
        guard let kingSquare = findKing(color) else { return false }

        let opponent = color.opposite

        return isSquareAttacked(kingSquare, by: opponent)
    }

    func hasAnyLegalMove(for color: PieceColor) -> Bool {
        for (from, piece) in board where piece.color == color {
            let moves = pseudoMoves(from: from, piece: piece)
            for to in moves {
                if isLegalAfterMove(from: from, to: to, color: color) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Pawn

    private func pawnMoves(from: Square, _ piece: Piece) -> Set<Square> {
        var moves = Set<Square>()
        let dir = piece.color == .white ? 1 : -1

        // Foward 1
        let one = Square(file: from.file, rank: from.rank + dir)
        if isInside(one), board[one] == nil {
            moves.insert(one)

            // Foward 2
            let startRank = piece.color == .white ? 1 : 6
            let two = Square(file: from.file, rank: from.rank + 2 * dir)
            if from.rank == startRank, board[two] == nil {
                moves.insert(two)
            }
        }

        // Captures
        for df in [-1, 1] {
            let cap = Square(file: from.file + df, rank: from.rank + dir)
            if isInside(cap),
                let target = board[cap],
                target.color != piece.color
            {
                moves.insert(cap)
            }
        }

        return moves
    }

    // MARK: - Sliding pieces

    private var rookDirs: [(Int, Int)] { [(1, 0), (-1, 0), (0, 1), (0, -1)] }
    private var bishopDirs: [(Int, Int)] {
        [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    }

    private func slidingMoves(
        from: Square,
        _ piece: Piece,
        _ dirs: [(Int, Int)]
    ) -> Set<Square> {

        var moves = Set<Square>()

        for (df, dr) in dirs {
            var f = from.file + df
            var r = from.rank + dr

            while isInside(file: f, rank: r) {
                let sq = Square(file: f, rank: r)

                if let target = board[sq] {
                    if target.color != piece.color {
                        moves.insert(sq)
                    }
                    break
                }

                moves.insert(sq)
                f += df
                r += dr
            }
        }

        return moves
    }

    private func slidingMoves(
        _ from: Square,
        _ piece: Piece,
        directions: [(Int, Int)]
    ) -> Set<Square> {

        var moves = Set<Square>()

        for (df, dr) in directions {
            var f = from.file + df
            var r = from.rank + dr

            while isInside(Square(file: f, rank: r)) {
                let sq = Square(file: f, rank: r)

                if let t = board[sq] {
                    if t.color != piece.color {
                        moves.insert(sq)
                    }
                    break
                }

                moves.insert(sq)
                f += df
                r += dr
            }
        }

        return moves
    }

    // MARK: - Knight

    private func knightMoves(from: Square, _ piece: Piece) -> Set<Square> {
        let offsets = [
            (1, 2), (2, 1), (2, -1), (1, -2),
            (-1, -2), (-2, -1), (-2, 1), (-1, 2),
        ]

        return Set(
            offsets.compactMap { df, dr in
                let sq = Square(file: from.file + df, rank: from.rank + dr)
                guard isInside(sq) else { return nil }
                if let t = board[sq], t.color == piece.color { return nil }
                return sq
            }
        )
    }

    // MARK: - King

    private func kingMoves(from: Square, _ piece: Piece) -> Set<Square> {
        var moves = Set<Square>()

        // ───── Normal king moves ─────
        for df in -1...1 {
            for dr in -1...1 {
                if df == 0 && dr == 0 { continue }
                let sq = Square(file: from.file + df, rank: from.rank + dr)
                guard isInside(sq) else { continue }
                if let t = board[sq], t.color == piece.color { continue }
                if isSquareAttacked(sq, by: piece.color.opposite) { continue }
                moves.insert(sq)
            }
        }

        // ───── Castling ─────
        addCastlingMoves(from: from, piece: piece, into: &moves)

        return moves
    }

    private func kingAttackMoves(from: Square, _ piece: Piece) -> Set<Square> {
        var moves = Set<Square>()

        for df in -1...1 {
            for dr in -1...1 {
                if df == 0 && dr == 0 { continue }
                let sq = Square(file: from.file + df, rank: from.rank + dr)
                guard isInside(sq) else { continue }
                moves.insert(sq)
            }
        }
        return moves
    }

    // MARK: - Helpers

    private func attackMoves(from: Square, _ piece: Piece) -> Set<Square> {
        switch piece.type {
        case .pawn: return pawnMoves(from: from, piece)
        case .knight: return knightMoves(from: from, piece)
        case .bishop: return slidingMoves(from, piece, directions: bishopDirs)
        case .rook: return slidingMoves(from, piece, directions: rookDirs)
        case .queen:
            return slidingMoves(from, piece, directions: bishopDirs + rookDirs)
        case .king: return kingAttackMoves(from: from, piece)
        }
    }

    func isSquareAttacked(_ square: Square, by color: PieceColor) -> Bool {
        for (from, piece) in board where piece.color == color {
            if attackMoves(from: from, piece).contains(square) {
                return true
            }
        }
        return false
    }

    private func findKing(_ color: PieceColor) -> Square? {
        for (square, piece) in board {
            if piece.type == .king && piece.color == color {
                return square
            }
        }
        return nil
    }

    private func wouldLeaveKingInCheck(from: Square, to: Square) -> Bool {
        guard let movingPiece = board[from] else { return false }

        let originalFrom = board[from]
        let originalTo = board[to]

        // ───── Make move (temporary) ─────
        board[to] = movingPiece
        board[from] = nil

        // Special case: king move → king square changes
        let kingSquare: Square
        if movingPiece.type == .king {
            kingSquare = to
        } else {
            guard let found = findKing(movingPiece.color) else {
                restoreMove(from: from, to: to, originalFrom, originalTo)
                return false
            }
            kingSquare = found
        }

        let inCheck = isSquareAttacked(
            kingSquare,
            by: movingPiece.color.opposite
        )

        // ───── Undo move ─────
        restoreMove(from: from, to: to, originalFrom, originalTo)

        return inCheck
    }

    private func restoreMove(
        from: Square,
        to: Square,
        _ originalFrom: Piece?,
        _ originalTo: Piece?
    ) {
        board[from] = originalFrom
        board[to] = originalTo
    }

    private func isLegalAfterMove(from: Square, to: Square, color: PieceColor)
        -> Bool
    {

        // Save state
        let captured = board[to]
        let moving = board[from]

        // Make move
        board[to] = moving
        board[from] = nil

        let inCheck = isKingInCheck(color: color)

        // Undo move
        board[from] = moving
        board[to] = captured

        return !inCheck
    }

    private func isInside(_ square: Square) -> Bool {
        isInside(file: square.file, rank: square.rank)
    }

    private func isInside(file: Int, rank: Int) -> Bool {
        (0..<8).contains(file) && (0..<8).contains(rank)
    }

    // MARK: Castling

    private func addCastlingMoves(
        from: Square,
        piece: Piece,
        into moves: inout Set<Square>
    ) {
        guard piece.type == .king else { return }

        if isKingInCheck(color: piece.color) {
            return
        }

        let enemy = piece.color.opposite

        if piece.color == .white && from == Square(file: 4, rank: 0) {
            // King side
            if castlingRights.whiteKingSide
                && board[Square(file: 5, rank: 0)] == nil
                && board[Square(file: 6, rank: 0)] == nil
                && !isSquareAttacked(Square(file: 5, rank: 0), by: enemy)
                && !isSquareAttacked(Square(file: 6, rank: 0), by: enemy)
            {
                moves.insert(Square(file: 6, rank: 0))  // g1
            }

            // Queen side
            if castlingRights.whiteQueenSide
                && board[Square(file: 3, rank: 0)] == nil
                && board[Square(file: 2, rank: 0)] == nil
                && board[Square(file: 1, rank: 0)] == nil
                && !isSquareAttacked(Square(file: 3, rank: 0), by: enemy)
                && !isSquareAttacked(Square(file: 2, rank: 0), by: enemy)
            {
                moves.insert(Square(file: 2, rank: 0))  // c1
            }
        }

        if piece.color == .black && from == Square(file: 4, rank: 7) {
            // King side
            if castlingRights.blackKingSide
                && board[Square(file: 5, rank: 7)] == nil
                && board[Square(file: 6, rank: 7)] == nil
                && !isSquareAttacked(Square(file: 5, rank: 7), by: enemy)
                && !isSquareAttacked(Square(file: 6, rank: 7), by: enemy)
            {
                moves.insert(Square(file: 6, rank: 7))  // g8
            }

            // Queen side
            if castlingRights.blackQueenSide
                && board[Square(file: 3, rank: 7)] == nil
                && board[Square(file: 2, rank: 7)] == nil
                && board[Square(file: 1, rank: 7)] == nil
                && !isSquareAttacked(Square(file: 3, rank: 7), by: enemy)
                && !isSquareAttacked(Square(file: 2, rank: 7), by: enemy)
            {
                moves.insert(Square(file: 2, rank: 7))  // c8
            }
        }
    }

}
