import Foundation

enum AppStoreConfiguration {
    static let appID = "6759681065"

    static var writeReviewURL: URL? {
        URL(string: "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review")
    }
}
