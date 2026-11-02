import CoreGraphics
import Testing

@testable import KAIActions

@Suite struct PointerMapperTests {
    private let mapper = PointerMapper(screen: CGRect(x: 0, y: 0, width: 1000, height: 800))

    @Test func centerOfCameraIsCenterOfScreen() {
        let p = mapper.screenPoint(forNormalized: CGPoint(x: 0.5, y: 0.5))
        #expect(abs(p.x - 499.5) < 1e-9)
        #expect(abs(p.y - 399.5) < 1e-9)
    }

    @Test func yIsFlippedBecauseScreenYGrowsDownward() {
        let top = mapper.screenPoint(forNormalized: CGPoint(x: 0.5, y: 0.8))
        let bottom = mapper.screenPoint(forNormalized: CGPoint(x: 0.5, y: 0.2))
        #expect(top.y == 0)
        #expect(bottom.y == 799)
    }

    @Test func regionEdgesReachScreenEdges() {
        #expect(mapper.screenPoint(forNormalized: CGPoint(x: 0.2, y: 0.5)).x == 0)
        #expect(mapper.screenPoint(forNormalized: CGPoint(x: 0.8, y: 0.5)).x == 999)
    }

    @Test func clampsOutsideTheRegion() {
        let p = mapper.screenPoint(forNormalized: CGPoint(x: 0.0, y: 1.0))
        #expect(p == CGPoint(x: 0, y: 0))
    }

    @Test func respectsScreenOrigin() {
        let second = PointerMapper(screen: CGRect(x: 1000, y: -200, width: 500, height: 400))
        let p = second.screenPoint(forNormalized: CGPoint(x: 0.2, y: 0.8))
        #expect(p == CGPoint(x: 1000, y: -200))
    }
}
