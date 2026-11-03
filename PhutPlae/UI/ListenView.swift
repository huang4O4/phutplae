import SwiftUI

struct ListenView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: UserSettings

    private var palette: HUDPalette {
        HUDPalette.forEmotion(app.liveEmotion, intensity: app.liveIntensity)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HUDBackground(palette: palette, energy: app.telemetry.energy)
                VStack(spacing: 12) {
                    topBar
                    Spacer(minLength: 0)
                    reactorRow
                    transcriptBlock
                    translationBlock
                    emotionBadge
                    if app.downloads.isWorking || app.phase == .downloading {
                        downloadMeter
                    }
                    if let error = app.errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    recentStrip
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.45), value: app.liveEmotion)
            .sheet(isPresented: $app.showPacks) {
                PackDownloadView()
                    .environmentObject(app)
                    .environmentObject(settings)
            }
        }
        .task {
            app.refreshVoiceInventory()
            if settings.canRunOffline {
                app.bootOnLaunch()
            } else {
                app.showPacks = true
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(statusHeadline)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.glow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(app.statusLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.muted)
                    .lineLimit(2)
            }
            Spacer()
            readinessPill
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.glow)
                    .padding(8)
                    .overlay(Circle().stroke(palette.glow.opacity(0.45), lineWidth: 1))
            }
            .accessibilityLabel("ตั้งค่า")
        }
    }

    private var readinessPill: some View {
        Text(app.readiness.hudLabel)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(palette.glow)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(Capsule().stroke(palette.glow.opacity(0.5), lineWidth: 1))
            .onTapGesture { app.showPacks = true }
    }

    private var reactorRow: some View {
        HStack(alignment: .center, spacing: 8) {
            HUDGraphPanel(
                title: "PITCH",
                unit: "Hz",
                valueText: app.telemetry.pitchHz > 0 ? String(format: "%.0f", app.telemetry.pitchHz) : "—",
                values: app.telemetry.pitchHistory,
                range: 70...350,
                palette: palette,
                alignment: .leading
            )
            .frame(width: 86)

            Button {
                Task { await app.toggleListening() }
            } label: {
                ArcReactorView(
                    palette: palette,
                    isListening: app.isListening,
                    isBusy: app.phase == .transcribing || app.phase == .translating,
                    isBooting: app.isBooting,
                    isReady: app.isModelsReady,
                    bootProgress: app.downloads.state.fraction,
                    energy: app.telemetry.energy,
                    waveform: app.telemetry.waveform
                )
            }
            .buttonStyle(.plain)
            .disabled(app.isBooting)
            .frame(maxWidth: 280)

            HUDGraphPanel(
                title: "LOUD",
                unit: "dB",
                valueText: String(format: "%.0f", app.telemetry.loudnessDB),
                values: app.telemetry.loudnessHistory,
                range: -80...0,
                palette: palette,
                alignment: .trailing
            )
            .frame(width: 86)
        }
        .frame(maxHeight: 280)
    }

    private var transcriptBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SRC · \(app.liveSourceLanguage?.shortHUD ?? "EN/ZH")")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(palette.muted)
            Text(app.liveSource.isEmpty ? "awaiting english or mandarin…" : app.liveSource)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundStyle(app.liveSource.isEmpty ? palette.muted : palette.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var translationBlock: some View {
        Text(app.liveTranslation.isEmpty ? "พร้อมแปลเป็นไทย" : app.liveTranslation)
            .font(.system(size: app.liveTranslation.isEmpty ? 22 : 34, weight: .semibold))
            .foregroundStyle(palette.glow)
            .shadow(color: palette.glow.opacity(0.55), radius: 16)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity)
    }

    private var emotionBadge: some View {
        HStack(spacing: 10) {
            Text(app.liveEmotion.emoji).font(.title2)
            Text("\(app.liveEmotion.hudCode)  \(Int(app.liveIntensity * 100))%  CONF \(Int(app.liveEmotionConfidence * 100))%")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.glow)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .overlay(Capsule().stroke(palette.glow.opacity(0.55), lineWidth: 1))
        .background(palette.glow.opacity(0.08), in: Capsule())
    }

    private var downloadMeter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(app.downloads.state.message.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.muted)
            ProgressView(value: app.downloads.state.fraction).tint(palette.glow)
        }
        .padding(10)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.glow.opacity(0.25), lineWidth: 1))
    }

    private var recentStrip: some View {
        Group {
            if let turn = app.turns.first {
                Text("LAST  \(turn.sourceLanguage.shortHUD)→TH  \(turn.latency.totalMs) ms")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.muted)
            }
        }
    }

    private var statusHeadline: String {
        let detected = app.liveSourceLanguage?.shortHUD ?? "EN/ZH"
        let latency: String = {
            if let last = app.lastLatency { return "\(last.totalMs) ms" }
            if app.liveLatencyMs > 0 { return "\(app.liveLatencyMs) ms" }
            return "— ms"
        }()
        return "\(detected) → TH  ·  ON-DEVICE  ·  \(latency)"
    }
}
