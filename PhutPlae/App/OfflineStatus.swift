import Foundation
import Network
import SwiftUI

enum OfflineReadiness: Equatable {
    case packsMissing
    case booting
    case readyOffline
    case readyOnline

    var hudLabel: String {
        switch self {
        case .packsMissing: return "PACKS MISSING"
        case .booting: return "BOOTING"
        case .readyOffline: return "OFFLINE READY"
        case .readyOnline: return "PACKS READY · NET ON"
        }
    }
}

@MainActor
final class PathMonitor: ObservableObject {
    @Published var isSatisfied = false
    nonisolated(unsafe) private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "phutplae.path")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isSatisfied = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    nonisolated deinit {
        monitor.cancel()
    }
}
