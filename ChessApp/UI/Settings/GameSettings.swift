//
//  GameSettings.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 16/1/26.
//

import Foundation
import Combine
import SwiftUI

final class GameSettings: ObservableObject {
    // Persisted user preference
    @AppStorage("side_selection")
    private var sideSelectionRaw: String = SideSelection.white.rawValue

    @Published var sideSelection: SideSelection = .white
    
    // Elo range 1347 to 3176
    @AppStorage("elo_rating")
    var elo: Double = 1347
    
    @AppStorage("show_legal_moves")
    var showLegalMoves = true

    private var isSyncing = false

    init() {
        sideSelection = SideSelection(rawValue: sideSelectionRaw) ?? .white
    }

    // Keep AppStorage and Published in sync
    func updateSide(_ newSide: SideSelection) {
        guard sideSelection != newSide else { return }
        sideSelection = newSide
        sideSelectionRaw = newSide.rawValue
    }
}
