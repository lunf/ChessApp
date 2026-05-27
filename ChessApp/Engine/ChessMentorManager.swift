//
//  ChessMentorManager.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 28/12/25.
//
import Foundation
import Combine

@MainActor
final class ChessMentorManager: ObservableObject {

    private let service: ChessMentorService
    private let settings: MentorSettings
    
    @Published private(set) var modelAvailable: Bool = false
    private var availabilityChecked = false
    
    init(service: ChessMentorService, settings: MentorSettings) {
        self.service = service
        self.settings = settings
    }
    
    func checkModelAvailability() {
        guard !availabilityChecked else { return }
        modelAvailable = service.isModelAvailable()
        availabilityChecked = true
    }
    
    func sendMove(_ payload: ChessMentorPayload) async throws -> String? {
        guard settings.isEnabled, modelAvailable else {
            return nil
        }
        
        // Call Apple Intelligence / Foundation Models
        return try await analyzeMove(payload)
    }

    private func analyzeMove(_ payload: ChessMentorPayload) async throws -> String {
        return try await service.analyzeMove(payload)
    }
}
