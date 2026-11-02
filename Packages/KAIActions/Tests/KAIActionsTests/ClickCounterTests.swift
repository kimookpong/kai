import CoreGraphics
import Testing

@testable import KAIActions

@Suite struct ClickCounterTests {
    private let here = CGPoint(x: 100, y: 100)

    @Test func firstClickIsASingleClick() {
        var c = ClickCounter()
        #expect(c.register(at: here, time: 0) == 1)
    }

    @Test func quickSecondClickInTheSamePlaceIsADoubleClick() {
        var c = ClickCounter()
        _ = c.register(at: here, time: 0)
        #expect(c.register(at: CGPoint(x: 103, y: 101), time: 0.3) == 2)
        #expect(c.register(at: here, time: 0.6) == 3)
    }

    @Test func slowSecondClickStartsOver() {
        var c = ClickCounter()
        _ = c.register(at: here, time: 0)
        #expect(c.register(at: here, time: 0.8) == 1)
    }

    @Test func clickInADifferentPlaceStartsOver() {
        var c = ClickCounter()
        _ = c.register(at: here, time: 0)
        #expect(c.register(at: CGPoint(x: 200, y: 100), time: 0.2) == 1)
    }
}
