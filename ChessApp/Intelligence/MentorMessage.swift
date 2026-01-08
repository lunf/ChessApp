//
//  MEntorMessage.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 29/12/25.
//

import Foundation

struct MentorMessage: Identifiable, Equatable {    
    enum Role {
        case ai
        case user
        case system
    }

    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()
}
