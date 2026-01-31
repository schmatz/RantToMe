//
//  RecordButtonView.swift
//  RantToMe
//

import SwiftUI

struct RecordButtonView: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var animationScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animationScale)

                Circle()
                    .fill(isRecording ? Color.red : Color.red.opacity(0.8))
                    .frame(width: 80, height: 80)

                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onChange(of: isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    animationScale = 1.1
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    animationScale = 1.0
                }
            }
        }
    }
}
