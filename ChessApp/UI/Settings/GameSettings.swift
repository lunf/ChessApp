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

    @AppStorage("show_move_list")
    var showMoveList = true

    @AppStorage("clock_preset")
    private var clockPresetRaw: String = ClockPreset.off.rawValue

    @Published var clockPreset: ClockPreset = .off

    init() {
        sideSelection = SideSelection(rawValue: sideSelectionRaw) ?? .white
        clockPreset = ClockPreset(rawValue: clockPresetRaw) ?? .off
    }

    // Keep AppStorage and Published in sync
    func updateSide(_ newSide: SideSelection) {
        guard sideSelection != newSide else { return }
        sideSelection = newSide
        sideSelectionRaw = newSide.rawValue
    }

    func updateClockPreset(_ newPreset: ClockPreset) {
        guard clockPreset != newPreset else { return }
        clockPreset = newPreset
        clockPresetRaw = newPreset.rawValue
    }
}
