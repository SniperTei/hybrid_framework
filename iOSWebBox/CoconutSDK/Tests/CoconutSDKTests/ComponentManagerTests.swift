import XCTest
import UIKit
@testable import CoconutSDK

@MainActor
final class ComponentManagerTests: XCTestCase {

    private var manager: ComponentManager { .shared }

    override func setUp() async throws {
        try await super.setUp()
        // Ensure clean slate and a usable shared context.
        await manager.cleanup()
        manager.setApplicationContext(UIApplication.shared)
    }

    override func tearDown() async throws {
        await manager.cleanup()
        try await super.tearDown()
    }

    func testRegisterAndLookup() async throws {
        let plugin = MockPlugin(name: "device")
        try await manager.register(plugin)

        XCTAssertNotNil(manager.getComponent(name: "device"))
        XCTAssertTrue(manager.getRegisteredComponents().contains("device"))
        XCTAssertTrue(manager.hasComponent(name: "device"))
        XCTAssertEqual(plugin.initCallCount, 1)
        XCTAssertTrue(plugin.isInitialized)
    }

    func testDuplicateRegisterKeepsFirstAndDoesNotReinit() async throws {
        let first = MockPlugin(name: "dup", handleResult: ["who": "first"])
        let second = MockPlugin(name: "dup", handleResult: ["who": "second"])

        try await manager.register(first)
        try await manager.register(second)

        // Second should not have replaced the first.
        XCTAssertEqual(first.initCallCount, 1)
        XCTAssertEqual(second.initCallCount, 0, "Duplicate register must not call initComponent on the second instance")
        XCTAssertTrue(manager.getRegisteredComponents().contains("dup"))
    }

    func testGetNonexistentReturnsNil() {
        XCTAssertNil(manager.getComponent(name: "does-not-exist"))
        XCTAssertFalse(manager.hasComponent(name: "does-not-exist"))
    }

    func testRegisterWithMissingDependencySilentlyFails() async throws {
        // B depends on "A" which is not registered.
        let pluginB = MockPlugin(name: "B", dependencies: ["A"])
        try await manager.register(pluginB)

        XCTAssertNil(manager.getComponent(name: "B"), "Component with unsatisfied dependency must not be registered")
        XCTAssertEqual(pluginB.initCallCount, 0, "initComponent must not be called when deps are missing")
    }

    func testRegisterWithSatisfiedDependencySucceeds() async throws {
        let pluginA = MockPlugin(name: "A")
        let pluginB = MockPlugin(name: "B", dependencies: ["A"])
        try await manager.register(pluginA)
        try await manager.register(pluginB)

        XCTAssertNotNil(manager.getComponent(name: "A"))
        XCTAssertNotNil(manager.getComponent(name: "B"))
    }

    func testUnregisterCallsCleanupAndRemoves() async throws {
        let plugin = MockPlugin(name: "removable")
        try await manager.register(plugin)

        await manager.unregister(name: "removable")

        XCTAssertNil(manager.getComponent(name: "removable"))
        XCTAssertEqual(plugin.cleanupCallCount, 1)
        XCTAssertFalse(plugin.isInitialized)
    }

    func testUnregisterUnknownIsNoop() async throws {
        // Should not crash
        await manager.unregister(name: "never-existed")
    }

    func testCleanupCallsCleanupOnAllAndClearsRegistry() async throws {
        let p1 = MockPlugin(name: "c1")
        let p2 = MockPlugin(name: "c2")
        try await manager.register(p1)
        try await manager.register(p2)

        await manager.cleanup()

        XCTAssertTrue(p1.cleanupCallCount == 1)
        XCTAssertTrue(p2.cleanupCallCount == 1)
        XCTAssertTrue(manager.getRegisteredComponents().isEmpty)
    }

    func testGetComponentInfoReturnsMetadata() async throws {
        // Register the dependency first so "meta" can be registered.
        let dep = MockPlugin(name: "dep")
        try await manager.register(dep)
        let plugin = MockPlugin(name: "meta", dependencies: ["dep"])
        try await manager.register(plugin)

        let info = manager.getComponentInfo(name: "meta")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.name, "meta")
        XCTAssertEqual(info?.version, "1.0.0")
        XCTAssertEqual(info?.dependencies, ["dep"])
        XCTAssertTrue((info?.isInitialized) ?? false)
    }

    func testGetComponentInfoForUnknownReturnsNil() {
        XCTAssertNil(manager.getComponentInfo(name: "ghost"))
    }
}
