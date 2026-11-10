import SwiftUI
import BaresipKit
import BaresipKitSwiftUI

struct EngineCallRow: View {
    @ObservedObject var call: BaresipPhoneCall

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(call.remoteDisplayName.isEmpty ? call.remoteURI : call.remoteDisplayName)
                .font(.headline)
                .lineLimit(1)
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .accessibilityIdentifier("engine.call.state")
            HStack(spacing: 16) {
                Button(call.isMuted ? "Unmute" : "Mute") {
                    Task { try? await call.setMuted(!call.isMuted) }
                }
                .disabled(!call.isConnected)
                Button(call.isOnHold ? "Resume" : "Hold") {
                    Task { try? await call.setOnHold(!call.isOnHold) }
                }
                .disabled(!call.isConnected && !call.isOnHold)
                Button("Hang up", role: .destructive) {
                    Task { try? await call.hangUp() }
                }
            }
            .buttonStyle(.borderless)
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        var parts = [String(describing: call.state)]
        if call.isHeldByRemote {
            parts.append("held by the other side")
        }
        if !call.audioCodec.isEmpty {
            parts.append(call.audioCodec)
        }
        if !call.videoCodec.isEmpty {
            parts.append(call.videoCodec)
        }
        return parts.joined(separator: " · ")
    }
}
