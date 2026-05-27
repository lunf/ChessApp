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
        case .bishop: return bishopPseudoMoves(from: from, piece: piece)
        case .rook: return rookPseudoMoves(from: from, piece: piece)
        case .queen: return queenPseudoMoves(from: from, piece: piece)
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
            if !legalMoves(from: from).isEmpty {
                return true
            }
        }
        return false
    }
    
    // MARK: Castling
    
    func isKingCastling(from: Square, to: Square, piece: Piece) -> Bool {
            piece.type == .king && abs(from.file - to.file) == 2
    }

    func performCastling(from: Square, to: Square, piece: Piece) {
        let rank = from.rank

        board[from] = nil
        board[to] = piece

        if to.file == 6 {
            // King-side
            moveRook(from: Square(file: 7, rank: rank),
                     to: Square(file: 5, rank: rank))
        } else if to.file == 2 {
            // Queen-side
            moveRook(from: Square(file: 0, rank: rank),
                     to: Square(file: 3, rank: rank))
        }

        clearCastlingRights(for: piece.color)
    }
    
    func updateCastlingRights(movingPiece: Piece, from: Square, capturedPiece: Piece?, capturedAt: Square) {
        if movingPiece.type == .king {
            clearCastlingRights(for: movingPiece.color)
        } else if movingPiece.type == .rook {
            clearCastlingRightsForRook(color: movingPiece.color, square: from)
        }

        if let capturedPiece, capturedPiece.type == .rook {
            clearCastlingRightsForRook(color: capturedPiece.color, square: capturedAt)
        }
    }

    func updateEnPassantTarget(piece: Piece, from: Square, to: Square) {
        guard piece.type == .pawn, abs(to.rank - from.rank) == 2 else { return }
        enPassantTarget = Square(file: from.file, rank: (from.rank + to.rank) / 2)
    }

    func isEnPassantCapture(from: Square, to: Square, piece: Piece, previousTarget: Square?) -> Bool {
        piece.type == .pawn
            && to == previousTarget
            && board[to] == nil
            && abs(to.file - from.file) == 1
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
            if from.rank == startRank, isInside(two), board[one] == nil, board[two] == nil {
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

        if let enPassantTarget,
           enPassantTarget.rank == from.rank + dir,
           abs(enPassantTarget.file - from.file) == 1 {
            let capturedPawnSquare = Square(file: enPassantTarget.file, rank: from.rank)
            if board[capturedPawnSquare] == Piece(type: .pawn, color: piece.color.opposite) {
                moves.insert(enPassantTarget)
            }
        }

        return moves
    }
    
    private func pawnAttackMoves(from: Square, _ piece: Piece) -> Set<Square> {
        let dir = piece.color == .white ? 1 : -1
        let attacks = [
            Square(file: from.file - 1, rank: from.rank + dir),
            Square(file: from.file + 1, rank: from.rank + dir)
        ]
        return Set(attacks.filter(isInside))
    }

    // MARK: - Sliding pieces

    private var rookDirs: [(Int, Int)] { [(1, 0), (-1, 0), (0, 1), (0, -1)] }
    private var bishopDirs: [(Int, Int)] {
        [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    }

    private func slidingMoves(from: Square, directions: [(Int, Int)],
                              occupied: [Square: Piece]) -> Set<Square> {

        var result = Set<Square>()
        let ownColor = occupied[from]?.color
        
        for (df, dr) in directions {
            var f = from.file + df
            var r = from.rank + dr

            while true {
                let sq = Square(file: f, rank: r)
                guard isInside(sq) else { break }

                if let blocker = occupied[sq] {
                    if blocker.color != ownColor {
                        result.insert(sq)
                    }
                    break
                }

                result.insert(sq)

                f += df
                r += dr
            }
        }

        return result
    }
    
    private func slidingAttackMoves(from: Square, directions: [(Int, Int)]) -> Set<Square> {

        var result = Set<Square>()

        for (df, dr) in directions {
            var f = from.file + df
            var r = from.rank + dr

            while true {
                let sq = Square(file: f, rank: r)
                guard isInside(sq) else { break }
                result.insert(sq)
                if board[sq] != nil { break }
                f += df
                r += dr
            }
        }
        return result
    }
    
    // MARK: Bishop move
    
    private func bishopAttackMoves(from: Square) -> Set<Square> {
        slidingAttackMoves(from: from, directions: bishopDirs)
    }
    
    private func bishopPseudoMoves(from: Square, piece: Piece) -> Set<Square> {
        slidingMoves(from: from, directions: bishopDirs, occupied: board)
    }
    
    // MARK: Rook move
    
    private func rookPseudoMoves(from: Square, piece: Piece) -> Set<Square> {
        slidingMoves(from: from, directions: rookDirs, occupied: board)
    }
    
    private func rookAttackMoves(from: Square) -> Set<Square> {
        slidingAttackMoves(from: from, directions: rookDirs)
    }
    
    // MARK: Queen
    
    private func queenPseudoMoves(from: Square, piece: Piece) -> Set<Square> {
        slidingMoves(from: from, directions: bishopDirs + rookDirs, occupied: board)
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
    
    private func knightAttackMoves(from: Square) -> Set<Square> {
        let offsets = [
            (1, 2), (2, 1), (2, -1), (1, -2),
            (-1, -2), (-2, -1), (-2, 1), (-1, 2)
        ]

        var attacks = Set<Square>()

        for (df, dr) in offsets {
            let sq = Square(file: from.file + df, rank: from.rank + dr)
            if isInside(sq) {
                attacks.insert(sq)
            }
        }

        return attacks
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
        case .pawn: return pawnAttackMoves(from: from, piece)
        case .knight: return knightAttackMoves(from: from)
        case .bishop: return bishopAttackMoves(from: from)
        case .rook: return rookAttackMoves(from: from)
        case .queen:
            return slidingAttackMoves(
                from: from,
                directions: bishopDirs + rookDirs
            )
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
        var enPassantCaptureSquare: Square?
        var enPassantCapturedPiece: Piece?

        if isEnPassantCapture(from: from, to: to, piece: movingPiece, previousTarget: enPassantTarget) {
            enPassantCaptureSquare = Square(file: to.file, rank: from.rank)
            if let captureSquare = enPassantCaptureSquare {
                enPassantCapturedPiece = board[captureSquare]
            }
        }

        // Track rook movement for castling
        var rookFrom: Square? = nil
        var rookTo: Square? = nil
        var rookPiece: Piece? = nil

        // Detect castling
        if movingPiece.type == .king && abs(from.file - to.file) == 2 {
            let rank = from.rank
            if to.file == 6 {
                // King-side
                rookFrom = Square(file: 7, rank: rank)
                rookTo   = Square(file: 5, rank: rank)
            } else if to.file == 2 {
                // Queen-side
                rookFrom = Square(file: 0, rank: rank)
                rookTo   = Square(file: 3, rank: rank)
            }
            if let rf = rookFrom {
                rookPiece = board[rf]
            }
        }

        // ───── Simulate move ─────
        board[to] = movingPiece
        board[from] = nil

        if let captureSquare = enPassantCaptureSquare {
            board[captureSquare] = nil
        }
        
        if let rf = rookFrom, let rt = rookTo {
            board[rt] = rookPiece
            board[rf] = nil
        }

        // Determine king square
        let kingSquare: Square
        if movingPiece.type == .king {
            kingSquare = to
        } else {
            guard let found = findKing(movingPiece.color) else {
                restoreAfterSimulation(from: from, to: to, originalFrom, originalTo, rookFrom, rookTo, rookPiece, enPassantCaptureSquare, enPassantCapturedPiece)
                return false
            }
            kingSquare = found
        }
        
        // IMPORTANT: attackMoves must never call pseudoMoves or legalMoves
        let inCheck = isSquareAttacked(kingSquare, by: movingPiece.color.opposite)
        
        // ───── Restore board ─────
        restoreAfterSimulation(from: from, to: to, originalFrom, originalTo, rookFrom, rookTo, rookPiece, enPassantCaptureSquare, enPassantCapturedPiece)

        return inCheck
    }

    private func restoreAfterSimulation(from: Square, to: Square,
                                        _ originalFrom: Piece?, _ originalTo: Piece?,
                                        _ rookFrom: Square?, _ rookTo: Square?, _ rookPiece: Piece?,
                                        _ enPassantCaptureSquare: Square?, _ enPassantCapturedPiece: Piece?) {
        
        // Restore king first, rook second
        board[from] = originalFrom
        board[to] = originalTo
        
        if let rf = rookFrom, let rt = rookTo {
            board[rf] = rookPiece
            board[rt] = nil
        }

        if let captureSquare = enPassantCaptureSquare {
            board[captureSquare] = enPassantCapturedPiece
        }
    }


    private func isInside(_ square: Square) -> Bool {
        isInside(file: square.file, rank: square.rank)
    }

    private func isInside(file: Int, rank: Int) -> Bool {
        (0..<8).contains(file) && (0..<8).contains(rank)
    }

    // MARK: Castling
    
    private func moveRook(from: Square, to: Square) {
        board[to] = board[from]
        board[from] = nil
    }
    
    private func clearCastlingRights(for color: PieceColor) {
        if color == .white {
            castlingRights.whiteKingSide = false
            castlingRights.whiteQueenSide = false
        } else {
            castlingRights.blackKingSide = false
            castlingRights.blackQueenSide = false
        }
    }

    private func clearCastlingRightsForRook(color: PieceColor, square: Square) {
        switch (color, square) {
        case (.white, Square(file: 0, rank: 0)):
            castlingRights.whiteQueenSide = false
        case (.white, Square(file: 7, rank: 0)):
            castlingRights.whiteKingSide = false
        case (.black, Square(file: 0, rank: 7)):
            castlingRights.blackQueenSide = false
        case (.black, Square(file: 7, rank: 7)):
            castlingRights.blackKingSide = false
        default:
            break
        }
    }

    private func addCastlingMoves(from: Square, piece: Piece, into moves: inout Set<Square>) {
        guard piece.type == .king else { return }
        
        if isKingInCheck(color: piece.color) {
            return
        }
        
        let enemy = piece.color.opposite
        
        if piece.color == .white && from == Square(file: 4, rank: 0) {
            
            // ───── King-side (white) ─────
            if castlingRights.whiteKingSide,
               board[Square(file: 7, rank: 0)] == Piece(type: .rook, color: .white),
               board[Square(file: 5, rank: 0)] == nil,
               board[Square(file: 6, rank: 0)] == nil,
               !isSquareAttacked(Square(file: 5, rank: 0), by: enemy),
               !isSquareAttacked(Square(file: 6, rank: 0), by: enemy)
            {
                moves.insert(Square(file: 6, rank: 0)) // g1
            }
            
            // ───── Queen-side (white) ─────
            if castlingRights.whiteQueenSide,
               board[Square(file: 0, rank: 0)] == Piece(type: .rook, color: .white),
               board[Square(file: 3, rank: 0)] == nil,
               board[Square(file: 2, rank: 0)] == nil,
               board[Square(file: 1, rank: 0)] == nil,
               !isSquareAttacked(Square(file: 3, rank: 0), by: enemy),
               !isSquareAttacked(Square(file: 2, rank: 0), by: enemy)
            {
                moves.insert(Square(file: 2, rank: 0)) // c1
            }
        }
        
        if piece.color == .black && from == Square(file: 4, rank: 7) {
            
            // ───── King-side (black) ─────
            if castlingRights.blackKingSide,
               board[Square(file: 7, rank: 7)] == Piece(type: .rook, color: .black),
               board[Square(file: 5, rank: 7)] == nil,
               board[Square(file: 6, rank: 7)] == nil,
               !isSquareAttacked(Square(file: 5, rank: 7), by: enemy),
               !isSquareAttacked(Square(file: 6, rank: 7), by: enemy)
            {
                moves.insert(Square(file: 6, rank: 7)) // g8
            }
            
            // ───── Queen-side (black) ─────
            if castlingRights.blackQueenSide,
               board[Square(file: 0, rank: 7)] == Piece(type: .rook, color: .black),
               board[Square(file: 3, rank: 7)] == nil,
               board[Square(file: 2, rank: 7)] == nil,
               board[Square(file: 1, rank: 7)] == nil,
               !isSquareAttacked(Square(file: 3, rank: 7), by: enemy),
               !isSquareAttacked(Square(file: 2, rank: 7), by: enemy)
            {
                moves.insert(Square(file: 2, rank: 7)) // c8
            }
        }
    }
}
