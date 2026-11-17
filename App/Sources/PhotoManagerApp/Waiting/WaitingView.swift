import PhotoManagerCore
import SwiftUI

/// Shown until an iPhone is connected, unlocked and trusted.
struct WaitingView: View {
    let device: DeviceInfo?

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                PulseRing()
                Image(systemName: "iphone")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.tint)
                    .frame(width: 132, height: 132)
                    .glassEffect(.regular, in: .circle)
            }
            .frame(width: 168, height: 168)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            GlassEffectContainer(spacing: 14) {
                HStack(spacing: 14) {
                    StepCard(number: 1, title: "Connect the cable", detail: "USB‑C or Lightning to this Mac.", isDone: device != nil)
                    StepCard(number: 2, title: "Unlock your iPhone", detail: "Photos are only readable while it is unlocked.", isDone: device != nil && device?.access != .locked)
                    StepCard(number: 3, title: "Tap “Trust”", detail: "Allow this computer when your iPhone asks.", isDone: device?.access == .ready)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            Label(status, systemImage: "")
                .labelStyle(StatusLabelStyle())
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch device?.access {
        case .locked: "Unlock your iPhone"
        case .needsTrust: "Trust this Mac"
        default: "Connect your iPhone"
        }
    }

    private var message: String {
        switch device?.access {
        case .locked: "\(device?.name ?? "Your iPhone") is connected but locked. Unlock it to see its photos."
        case .needsTrust: "Unlock \(device?.name ?? "your iPhone"). If it asks, tap “Trust” and enter its passcode."
        default: "Plug it into this Mac with a cable. Photo Manager detects it automatically and shows its photos and videos."
        }
    }

    private var status: String {
        device == nil ? "Searching for devices…" : "Waiting for \(device?.name ?? "iPhone")…"
    }
}

private struct StepCard: View {
    let number: Int
    let title: String
    let detail: String
    let isDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle().fill(isDone ? Color.green : Color.accentColor)
                if isDone {
                    Image(systemName: "checkmark").font(.caption.bold())
                } else {
                    Text("\(number)").font(.callout.bold())
                }
            }
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)

            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        // Same height for every card, content pinned to the top.
        .frame(width: 200, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : "Pending")
    }
}

private struct StatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            configuration.title.font(.callout.weight(.medium))
        }
    }
}

private struct PulseRing: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.18))
            .scaleEffect(expanded ? 1.35 : 0.85)
            .opacity(expanded ? 0 : 0.55)
            .onAppear {
                withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { expanded = true }
            }
            .accessibilityHidden(true)
    }
}
