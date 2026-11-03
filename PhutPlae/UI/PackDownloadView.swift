import SwiftUI

struct PackDownloadView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: UserSettings
    @Environment(\.dismiss) private var dismiss

    private var palette: HUDPalette {
        HUDPalette.forEmotion(.neutral, intensity: 0.4)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HUDPalette.void.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DOWNLOAD BEFORE TRAVEL")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.glow)
                        Text("โหลดชุดภาษาตอนมีเน็ตครั้งเดียว แล้วปิดเครื่องบินได้ทั้งทริป แอปไม่ฝังโมเดลในไฟล์ติดตั้ง")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.text)

                        ForEach(LanguagePackCatalog.packs(whisper: settings.whisperSize)) { pack in
                            packRow(pack)
                        }

                        Button {
                            Task { await app.downloadAllPacks() }
                        } label: {
                            Text("โหลดทุกชุด")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(palette.glow, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(HUDPalette.void)
                        }

                        if settings.canRunOffline {
                            Button("เข้าสู่ HUD") {
                                app.showPacks = false
                                dismiss()
                                app.bootOnLaunch()
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(palette.glow)
                        }

                        if let error = app.errorMessage {
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("ชุดภาษาก่อนเดินทาง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func packRow(_ pack: LanguagePack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pack.thaiTitle)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                Spacer()
                Text(isDownloaded(pack) ? "ON DISK" : "NEEDED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isDownloaded(pack) ? palette.glow : palette.muted)
            }
            Text(pack.detail)
                .font(.footnote)
                .foregroundStyle(palette.muted)
            Button(isDownloaded(pack) ? "โหลดใหม่" : "ดาวน์โหลดชุดนี้") {
                Task { await app.downloadPack(pack) }
            }
            .disabled(app.phase == .downloading)
        }
        .padding(14)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.glow.opacity(0.25), lineWidth: 1))
    }

    private func isDownloaded(_ pack: LanguagePack) -> Bool {
        if pack.includesSER { return settings.downloadedSERPack }
        if pack.whisper != nil { return settings.downloadedWhisperPack }
        if pack.translator == .typhoon3b { return settings.downloadedEnglishPack }
        if pack.translator == .qwen3b { return settings.downloadedChinesePack }
        return false
    }
}
