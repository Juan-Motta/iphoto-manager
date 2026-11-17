import Testing
@testable import PhotoManagerAdapters

/// A file count that grows on a schedule, like ImageCaptureCore filling `mediaFiles`
/// after it already reported the catalog as complete.
@MainActor
private final class GrowingCatalog {
    private let start = ContinuousClock.now
    private let steps: [(after: Duration, count: Int)]

    init(_ steps: [(after: Duration, count: Int)]) { self.steps = steps }

    var count: Int {
        let elapsed = ContinuousClock.now - start
        return steps.last { elapsed >= $0.after }?.count ?? 0
    }
}

@Suite("Catalog settling")
@MainActor
struct CatalogSettlingTests {
    @Test func waitsForFilesThatArriveAfterTheReadySignal() async {
        // Seen on a real iPhone: "catalog ready" with 0 files, 4775 files about 280 ms later.
        let catalog = GrowingCatalog([(.zero, 0), (.milliseconds(120), 4_775)])
        let count = await CatalogSettling.waitUntilStable(quietPeriod: .milliseconds(250), timeout: .seconds(5)) { catalog.count }
        #expect(count == 4_775)
    }

    @Test func waitsWhileFilesKeepArriving() async {
        let catalog = GrowingCatalog([(.zero, 10), (.milliseconds(100), 20), (.milliseconds(200), 30), (.milliseconds(300), 40)])
        let count = await CatalogSettling.waitUntilStable(quietPeriod: .milliseconds(200), timeout: .seconds(5)) { catalog.count }
        #expect(count == 40)
    }

    @Test func anEmptyIPhoneStillReturns() async {
        let start = ContinuousClock.now
        let count = await CatalogSettling.waitUntilStable(quietPeriod: .milliseconds(100), timeout: .seconds(5)) { 0 }
        #expect(count == 0)
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    @Test func givesUpAtTheTimeout() async {
        var calls = 0
        let start = ContinuousClock.now
        // A count that never settles must not block the library forever.
        let count = await CatalogSettling.waitUntilStable(quietPeriod: .milliseconds(200), timeout: .milliseconds(400)) {
            calls += 1
            return calls
        }
        #expect(count > 0)
        #expect(ContinuousClock.now - start < .seconds(1))
    }
}
