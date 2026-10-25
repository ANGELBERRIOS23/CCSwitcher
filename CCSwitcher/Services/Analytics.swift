import Foundation
import Aptabase

/// Launch counting only. Keep account, credential, conversation, and usage data
/// out of this service and do not add custom event properties.
@MainActor
enum Analytics {
    static let enabledKey = "analyticsEnabled"
    private static var didTrackLaunch = false

    static func trackLaunch() {
        guard !didTrackLaunch else { return }
        didTrackLaunch = true

        // An absent preference means enabled, matching the Settings toggle.
        // Check before initializing the SDK so opted-out launches do nothing.
        let enabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        guard enabled else { return }

        Aptabase.shared.initialize(appKey: "A-US-6303033660")
        Aptabase.shared.trackEvent("app_launched")
    }
}
