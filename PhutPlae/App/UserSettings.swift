import Foundation
import SwiftUI

@MainActor
final class UserSettings: ObservableObject {
    @AppStorage("whisperSize") var whisperSizeRaw: String = WhisperModelSize.base.rawValue
    @AppStorage("translatorPolicy") var translatorPolicyRaw: String = TranslatorPolicy.automatic.rawValue
    @AppStorage("voiceSpeed") var voiceSpeed: Double = 1.0
    @AppStorage("hasCompletedOnboardingDownload") var hasCompletedOnboardingDownload = false
    @AppStorage("downloadedWhisperPack") var downloadedWhisperPack = false
    @AppStorage("downloadedEnglishPack") var downloadedEnglishPack = false
    @AppStorage("downloadedChinesePack") var downloadedChinesePack = false
    @AppStorage("downloadedSERPack") var downloadedSERPack = false

    var whisperSize: WhisperModelSize {
        get { WhisperModelSize(rawValue: whisperSizeRaw) ?? .base }
        set { whisperSizeRaw = newValue.rawValue }
    }

    var translatorPolicy: TranslatorPolicy {
        get { TranslatorPolicy(rawValue: translatorPolicyRaw) ?? .automatic }
        set { translatorPolicyRaw = newValue.rawValue }
    }

    var clampedVoiceSpeed: Double {
        min(1.4, max(0.7, voiceSpeed))
    }

    var packsReadyForTravel: Bool {
        downloadedWhisperPack && downloadedEnglishPack && downloadedChinesePack && downloadedSERPack
    }

    var canRunOffline: Bool {
        downloadedWhisperPack && (downloadedEnglishPack || downloadedChinesePack)
    }
}
