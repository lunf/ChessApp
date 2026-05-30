//
//  SettingsView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 25/12/25.
//
import SwiftUI

struct SettingsView: View {
    @ObservedObject var mentorSettings: MentorSettings
    @Binding var sideSelection: SideSelection
    @Binding var showLegalMoves: Bool
    @Binding var showMoveList: Bool
    @Binding var elo: Double
    @Binding var clockPreset: ClockPreset

    var body: some View {
        Form {
            Section("Play As") {
                Picker("Side", selection: $sideSelection) {
                    ForEach(SideSelection.allCases) { side in
                        Text(side.rawValue).tag(side)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Gameplay") {
                Toggle("Show move hints", isOn: $showLegalMoves)
                Toggle("Show move list", isOn: $showMoveList)

                Picker("Clock", selection: $clockPreset) {
                    ForEach(ClockPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
            }

            Section("Engine Strength") {
                Slider(
                    value: $elo,
                    in: 1347...3176,
                    step: 200
                )
                Text("ELO: \(Int(elo))")
                    .font(.caption)
            }
            
            Section("AI Mentor") {
               Toggle("Enable AI mentor", isOn: $mentorSettings.isEnabled)

               if mentorSettings.isEnabled {
                   Toggle("Force English responses", isOn: $mentorSettings.forceEnglish)
                   
                   Text("Mentor Prompt")
                       .font(.caption)
                       .foregroundColor(.secondary)

                   TextEditor(text: $mentorSettings.prompt)
                       .frame(minHeight: 120)
                       .font(.body)
                       .overlay(
                           RoundedRectangle(cornerRadius: 8)
                               .stroke(Color.secondary.opacity(0.3))
                       )
               }
           }
        }
    }
}
