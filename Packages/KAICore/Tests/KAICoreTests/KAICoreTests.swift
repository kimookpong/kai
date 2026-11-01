import Foundation
import Testing
@testable import KAICore

@Suite struct EventBusTests {
    @Test func deliversToAllSubscribers() async {
        let bus = EventBus()
        let a = await bus.subscribe()
        let b = await bus.subscribe()
        await bus.publish(.gestureDetected(name: "pinch"))
        var ia = a.makeAsyncIterator(), ib = b.makeAsyncIterator()
        #expect(await ia.next() == .gestureDetected(name: "pinch"))
        #expect(await ib.next() == .gestureDetected(name: "pinch"))
    }

    @Test func removesSubscriberWhenConsumerStops() async throws {
        let bus = EventBus()
        let task = Task {
            for await _ in await bus.subscribe() {}
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(await bus.subscriberCount == 1)
        task.cancel()
        try await Task.sleep(for: .milliseconds(100))
        #expect(await bus.subscriberCount == 0)
    }

    @Test func keepsOnlyNewestWhenConsumerIsSlow() async {
        let bus = EventBus()
        let stream = await bus.subscribe(bufferingNewest: 2)
        for i in 0..<5 { await bus.publish(.voiceCommandReceived(text: "\(i)")) }
        var it = stream.makeAsyncIterator()
        #expect(await it.next() == .voiceCommandReceived(text: "3"))
        #expect(await it.next() == .voiceCommandReceived(text: "4"))
    }
}

@Suite struct ConfigTests {
    private func tempStore() -> ConfigStore {
        ConfigStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("config.json"))
    }

    @Test func missingFileGivesDefaults() throws {
        #expect(try tempStore().load() == KAIConfig())
    }

    @Test func roundTrips() throws {
        let store = tempStore()
        var c = KAIConfig()
        c.gesture.anchor = "palm"
        c.privacy.allowCloudAI = true
        try store.save(c)
        #expect(try store.load() == c)
    }

    @Test func refusesConfigFromNewerVersion() throws {
        let store = tempStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 99}"#.utf8).write(to: store.url)
        #expect(throws: ConfigError.newerThanSupported(found: 99, supported: KAIConfig.currentVersion)) {
            try store.load()
        }
    }

    @Test func newerFileIsNotOverwrittenByFailedLoad() throws {
        let store = tempStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data(#"{"schemaVersion": 99}"#.utf8)
        try original.write(to: store.url)
        _ = try? store.load()
        #expect(try Data(contentsOf: store.url) == original)
    }
}

@Suite struct PermissionTests {
    @Test func everyPermissionHasARationale() {
        for p in Permission.allCases { #expect(!p.rationale.isEmpty) }
    }

    @Test func systemCheckerAnswersForEveryPermission() {
        let checker = SystemPermissionChecker()
        for p in Permission.allCases { _ = checker.status(for: p) }
    }
}
