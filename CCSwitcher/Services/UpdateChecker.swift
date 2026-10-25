import Combine
import Foundation
import AppKit
import Sparkle
import SwiftUI

/// Thin ObservableObject wrapper around Sparkle's `SPUStandardUpdaterController`.
/// Keeps the existing call-site API (`checkForUpdates(manual:)`,
/// `@Published var isChecking`) so `CCSwitcherApp.swift` and `SettingsView.swift`
/// don't need to change. Sparkle owns its own progress UI (download sheet,
/// release-notes window, restart prompt), so `isChecking` is kept for source
/// compatibility but is never flipped — clicking the button always shows
/// Sparkle's UI immediately, which provides its own feedback.
@MainActor
final class UpdateChecker: ObservableObject {
    /// Source-compat shim. Sparkle's UI is responsible for visible progress.
    @Published var isChecking = false

    @Published var automaticallyChecksForUpdates: Bool = false {
        didSet {
            guard controller.updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates else { return }
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            if !automaticallyChecksForUpdates {
                automaticallyDownloadsUpdates = false
            }
        }
    }

    @Published var automaticallyDownloadsUpdates: Bool = false {
        didSet {
            guard controller.updater.automaticallyDownloadsUpdates != automaticallyDownloadsUpdates else { return }
            controller.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }

    private let controller: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()

    init() {
        // `startingUpdater: true` enables Sparkle's automatic background
        // checks at the interval configured by Sparkle (default: 1 day).
        // No delegates needed: standard UI behavior is what we want.
        let ctrl = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = ctrl
        self.automaticallyChecksForUpdates = ctrl.updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = ctrl.updater.automaticallyDownloadsUpdates

        ctrl.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self, self.automaticallyChecksForUpdates != newValue else { return }
                self.automaticallyChecksForUpdates = newValue
            }
            .store(in: &cancellables)

        ctrl.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self, self.automaticallyDownloadsUpdates != newValue else { return }
                self.automaticallyDownloadsUpdates = newValue
            }
            .store(in: &cancellables)
    }

    /// Manual = user-initiated; shows Sparkle's full UI including
    /// "you're up to date" feedback when no update is available.
    /// Background = silent unless an update is found.
    func checkForUpdates(manual: Bool = false) {
        if manual {
            controller.checkForUpdates(nil)
        } else {
            controller.updater.checkForUpdatesInBackground()
        }
    }
}
