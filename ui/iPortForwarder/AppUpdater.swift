import AppKit

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
    }
}

enum AppUpdater {
    static private let owner = "hronro"
    static private let repo = "iPortForwarder"

    static private let lastCheckKey = "AppUpdater.lastCheckDate"
    static private let skippedVersionKey = "AppUpdater.skippedVersion"
    static private let backgroundCheckInterval: TimeInterval = 24 * 60 * 60

    static func checkForUpdates(explicitly: Bool = false) async {
        if !explicitly, let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed >= 0 && elapsed < backgroundCheckInterval {
                return
            }
        }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"

        let url = URL(string: urlString)!

        let data: Data, response: URLResponse
        do {
            let r = try await URLSession.shared.data(from: url)
            (data, response) = r
        } catch {
            if explicitly {
                await showErrorDialog(error)
            }
            return
        }

        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
            if explicitly {
                await showErrorDialog("Failed to obtain information about the latest release.")
            }

            return
        }

        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            if explicitly {
                await showErrorDialog("Failed to decode GitHub release JSON: \(error.localizedDescription)")
            }

            return
        }

        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        guard self.compareVersions(latestVersion, currentVersion) else {
            return
        }

        if !explicitly,
           let skipped = UserDefaults.standard.string(forKey: skippedVersionKey),
           skipped == latestVersion {
            return
        }

        await self.presentUpdate(latestVersion)
    }

    private static func compareVersions(_ version1: String, _ version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0

            if v1 > v2 {
                return true
            } else if v1 < v2 {
                return false
            }
        }

        return false
    }

    @MainActor private static func presentUpdate(_ newVersion: String) {
        let alert = NSAlert()
        alert.messageText = "iPortForwarder v\(newVersion) is available!"
        alert.addButton(withTitle: "View Release Page")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Skip This Version")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(URL(string: "https://github.com/\(owner)/\(repo)/releases")!)
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(newVersion, forKey: skippedVersionKey)
        default:
            break
        }
    }
}
