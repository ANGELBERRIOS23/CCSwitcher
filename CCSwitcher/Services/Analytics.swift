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

        // Fork build: never count launches of an unofficial build in the
        // upstream author's statistics, whatever the Settings toggle says.
        let enabled = false
        guard enabled else { return }

        Aptabase.shared.initialize(appKey: "A-US-6303033660")
        Aptabase.shared.trackEvent("app_launched")
    }
}
