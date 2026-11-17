import Foundation

enum CatalogSettling {
    /// ImageCaptureCore reports an iPhone's catalog as complete before `mediaFiles` is filled in
    /// (a real iPhone reported 0 files, then 4775 files 280 ms later). Reading at that signal
    /// would show an empty library, so this polls the count until it stops changing for
    /// `quietPeriod`, or until `timeout`, and returns the last count.
    @MainActor
    static func waitUntilStable(
        quietPeriod: Duration = .milliseconds(600),
        timeout: Duration = .seconds(20),
        poll: Duration = .milliseconds(50),
        count: () -> Int
    ) async -> Int {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var last = count()
        var lastChange = clock.now
        while clock.now < deadline, clock.now - lastChange < quietPeriod {
            try? await Task.sleep(for: poll)
            let current = count()
            if current != last {
                last = current
                lastChange = clock.now
            }
        }
        return last
    }
}
