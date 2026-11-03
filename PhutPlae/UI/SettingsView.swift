import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: UserSettings

    private var palette: HUDPalette {
        HUDPalette.forEmotion(app.liveEmotion, intensity: max(0.25, app.liveIntensity))
    }

    var body: some View {
        ZStack {
            HUDPalette.void.ignoresSafeArea()
            Form {
                Section("สถานะออฟไลน์") {
                    Text(app.readiness.hudLabel)
                    Text(settings.packsReadyForTravel
                         ? "มีชุดฟังเสียง + อังกฤษ→ไทย + จีน→ไทย ในเครื่องแล้ว ใช้โหมดเครื่องบินได้"
                         : "ยังขาดชุดภาษา เปิดหน้าดาวน์โหลดก่อนขึ้นเครื่อง")
                        .font(.footnote)
                    Button("เปิดหน้าชุดภาษาก่อนเดินทาง") {
                        app.showPacks = true
                    }
                }

                Section("โมเดลฟังเสียง · Whisper หลายภาษา") {
                    Picker("Whisper", selection: $settings.whisperSizeRaw) {
                        ForEach(WhisperModelSize.allCases) { size in
                            Text(size.thaiLabel).tag(size.rawValue)
                        }
                    }
                    Text(settings.whisperSize.footnote).font(.footnote)
                    Text("ไม่ใช้รุ่น .en เพราะฟังจีนกลางไม่ได้")
                        .font(.footnote)
                }

                Section("โมเดลแปล EN/ZH → TH") {
                    Picker("นโยบาย", selection: $settings.translatorPolicyRaw) {
                        ForEach(TranslatorPolicy.allCases) { policy in
                            Text(policy.thaiLabel).tag(policy.rawValue)
                        }
                    }
                    Text(settings.translatorPolicy.footnote).font(.footnote)
                }

                Section("ความเร็วเสียงไทย") {
                    Slider(value: $settings.voiceSpeed, in: 0.7...1.4, step: 0.05)
                    Text("×\(settings.voiceSpeed.formatted(.number.precision(.fractionLength(2))))")
                        .font(.footnote)
                }

                Section("เสียงไทยในระบบ") {
                    if app.hasEnhancedThaiVoice {
                        Text("พบเสียงไทย Enhanced/Premium แล้ว")
                            .font(.footnote)
                    } else {
                        Text("แนะนำให้ดาวน์โหลดเสียงไทย Enhanced: การตั้งค่า → การช่วยการเข้าถึง → พูดเนื้อหา → เสียง → ไทย")
                            .font(.footnote)
                    }
                    Button("ตรวจเสียงอีกครั้ง") { app.refreshVoiceInventory() }
                }

                Section("หน่วยความจำ") {
                    Text("โมเดลโหลดทันทีตอนเปิดแอป และคืน RAM เมื่อเข้าเบื้องหลัง เพราะเซสชันสั้นกว่า 3 นาที")
                        .font(.footnote)
                    Button("บูตโมเดลใหม่") {
                        Task { await app.bootstrapIfNeeded() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .tint(palette.glow)
        }
        .navigationTitle("ตั้งค่า")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
