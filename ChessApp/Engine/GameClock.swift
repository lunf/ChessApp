//
//  GameClock.swift
//  ChessApp
//

import Foundation

enum ClockPreset: String, CaseIterable, Identifiable {
    case off
    case blitz3Plus2
    case blitz5Plus0
    case rapid10Plus0
    case rapid15Plus10
    case classical30Plus0
    case classical90Plus30

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:
            return "Off"
        case .blitz3Plus2:
            return "3+2 Blitz"
        case .blitz5Plus0:
            return "5+0 Blitz"
        case .rapid10Plus0:
            return "10+0 Rapid"
        case .rapid15Plus10:
            return "15+10 Rapid"
        case .classical30Plus0:
            return "30+0 Classical"
        case .classical90Plus30:
            return "90+30 Classical"
        }
    }

    var initialSeconds: Int {
        switch self {
        case .off:
            return 0
        case .blitz3Plus2:
            return 3 * 60
        case .blitz5Plus0:
            return 5 * 60
        case .rapid10Plus0:
            return 10 * 60
        case .rapid15Plus10:
            return 15 * 60
        case .classical30Plus0:
            return 30 * 60
        case .classical90Plus30:
            return 90 * 60
        }
    }

    var incrementSeconds: Int {
        switch self {
        case .off, .blitz5Plus0, .rapid10Plus0, .classical30Plus0:
            return 0
        case .blitz3Plus2:
            return 2
        case .rapid15Plus10:
            return 10
        case .classical90Plus30:
            return 30
        }
    }

    var isEnabled: Bool {
        self != .off
    }
}

enum ClockFormatter {
    static func display(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let remainingSeconds = clamped % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}
